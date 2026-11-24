package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"tandem/core/linkmanager"
	"tandem/core/pal"
	"tandem/core/pairing"
)

// ServerConfig configures the local tandemd API server.
type ServerConfig struct {
	BindAddr   string // strictly "127.0.0.1:8385" or loopback
	APIKey     string
	Version    string
	DeviceID   string
	DeviceName string
}

// Server exposes the localhost REST and Event API for UI clients (Flutter / CLI).
type Server struct {
	cfg         ServerConfig
	palAdapter  pal.Network
	fwAdapter   pal.Firewall
	linkMgr     *linkmanager.Manager
	pairingSvc  *pairing.Service
	httpServer  *http.Server
	mu          sync.RWMutex
	devices     map[string]map[string]interface{}
	folders     map[string]map[string]interface{}
	sendSessions map[string]map[string]interface{}
	eventChans  map[chan string]struct{}
}

func NewServer(
	cfg ServerConfig,
	palAdapter pal.Network,
	fwAdapter pal.Firewall,
	linkMgr *linkmanager.Manager,
	pairingSvc *pairing.Service,
) *Server {
	if cfg.BindAddr == "" {
		cfg.BindAddr = "127.0.0.1:8385"
	}
	if cfg.Version == "" {
		cfg.Version = "0.1.0-alpha"
	}

	s := &Server{
		cfg:          cfg,
		palAdapter:   palAdapter,
		fwAdapter:    fwAdapter,
		linkMgr:      linkMgr,
		pairingSvc:   pairingSvc,
		devices:      make(map[string]map[string]interface{}),
		folders:      make(map[string]map[string]interface{}),
		sendSessions: make(map[string]map[string]interface{}),
		eventChans:   make(map[chan string]struct{}),
	}

	return s
}

// Start begins listening on the configured loopback address.
func (s *Server) Start(ctx context.Context) error {
	mux := http.NewServeMux()

	// Register routes with auth middleware
	mux.HandleFunc("/api/v1/status", s.requireAuth(s.handleStatus))
	mux.HandleFunc("/api/v1/health", s.requireAuth(s.handleHealth))
	mux.HandleFunc("/api/v1/devices", s.requireAuth(s.handleDevices))
	mux.HandleFunc("/api/v1/devices/", s.requireAuth(s.handleDeviceByID))
	mux.HandleFunc("/api/v1/folders", s.requireAuth(s.handleFolders))
	mux.HandleFunc("/api/v1/folders/", s.requireAuth(s.handleFolderByID))
	mux.HandleFunc("/api/v1/send", s.requireAuth(s.handleSend))
	mux.HandleFunc("/api/v1/send/", s.requireAuth(s.handleSendByID))
	mux.HandleFunc("/api/v1/pairing/code", s.requireAuth(s.handlePairingCode))
	mux.HandleFunc("/api/v1/pairing/confirm", s.requireAuth(s.handlePairingConfirm))
	mux.HandleFunc("/api/v1/events", s.requireAuth(s.handleEventsSSE))

	listener, err := net.Listen("tcp", s.cfg.BindAddr)
	if err != nil {
		return fmt.Errorf("failed to bind loopback API on %s: %w", s.cfg.BindAddr, err)
	}

	s.httpServer = &http.Server{
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 0, // Streaming SSE requires no write timeout
	}

	go func() {
		<-ctx.Done()
		_ = s.httpServer.Shutdown(context.Background())
	}()

	return s.httpServer.Serve(listener)
}

// Stop shuts down the HTTP server.
func (s *Server) Stop() error {
	if s.httpServer != nil {
		return s.httpServer.Close()
	}
	return nil
}

// Authentication middleware enforcing Bearer token verification.
func (s *Server) requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Enforce loopback check
		host, _, _ := net.SplitHostPort(r.RemoteAddr)
		isLoopback := host == "127.0.0.1" || host == "::1" || host == "localhost"
		if ip := net.ParseIP(host); ip != nil {
			if ip.IsLoopback() || (ip.To4() != nil && ip.To4().IsLoopback()) {
				isLoopback = true
			}
		}
		if !isLoopback {
			http.Error(w, "Forbidden: loopback access only", http.StatusForbidden)
			return
		}

		if s.cfg.APIKey != "" {
			authHeader := r.Header.Get("Authorization")
			token := strings.TrimPrefix(authHeader, "Bearer ")
			if token != s.cfg.APIKey {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusUnauthorized)
				_ = json.NewEncoder(w).Encode(map[string]string{
					"code":    "unauthorized",
					"message": "Invalid or missing API key",
				})
				return
			}
		}

		w.Header().Set("Content-Type", "application/json")
		next(w, r)
	}
}

// ================= API Handlers =================

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	s.mu.RLock()
	transfers := len(s.sendSessions)
	s.mu.RUnlock()

	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"version":         s.cfg.Version,
		"myDeviceId":      s.cfg.DeviceID,
		"myDeviceName":    s.cfg.DeviceName,
		"state":           "idle",
		"hasInternet":     false, // treated as normal state, not error (Section 5.4)
		"activeTransfers": transfers,
	})
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ports := []pal.Port{
		{Port: 22000, Protocol: "tcp"},
		{Port: 22000, Protocol: "udp"},
		{Port: 21027, Protocol: "udp"},
	}
	fwStatus, _ := s.fwAdapter.Status(ports)
	remediation := s.fwAdapter.Remediation(ports)

	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"firewallState":       fwStatus,
		"firewallRemediation": remediation.Description,
		"discoveryWorks":      true,
		"storageOk":           true,
		"inotifyExhausted":    false,
		"batteryOptimized":    false,
	})
}

func (s *Server) handleDevices(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.mu.RLock()
		defer s.mu.RUnlock()
		list := make([]interface{}, 0, len(s.devices))
		for _, dev := range s.devices {
			list = append(list, dev)
		}
		_ = json.NewEncoder(w).Encode(list)

	case http.MethodPost:
		var req struct {
			DeviceID    string `json:"deviceId"`
			Name        string `json:"name"`
			AddressHint string `json:"addressHint"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.DeviceID == "" {
			w.WriteHeader(http.StatusBadRequest)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "bad_request", "message": "Missing deviceId"})
			return
		}

		s.mu.Lock()
		dev := map[string]interface{}{
			"id":        req.DeviceID,
			"name":      req.Name,
			"isPaired":  true,
			"linkState": linkmanager.LinkStateConnecting,
			"lastSeen":  time.Now().Format(time.RFC3339),
			"addresses": []string{},
		}
		if req.AddressHint != "" {
			dev["addresses"] = []string{req.AddressHint}
		}
		s.devices[req.DeviceID] = dev
		s.mu.Unlock()

		s.broadcastEvent(fmt.Sprintf(`{"event":"device_paired","deviceId":%q}`, req.DeviceID))

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(dev)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleDeviceByID(w http.ResponseWriter, r *http.Request) {
	deviceID := strings.TrimPrefix(r.URL.Path, "/api/v1/devices/")
	if deviceID == "" {
		http.NotFound(w, r)
		return
	}

	switch r.Method {
	case http.MethodGet:
		s.mu.RLock()
		dev, exists := s.devices[deviceID]
		s.mu.RUnlock()
		if !exists {
			w.WriteHeader(http.StatusNotFound)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "not_found", "message": "Device not found"})
			return
		}
		_ = json.NewEncoder(w).Encode(dev)

	case http.MethodDelete:
		s.mu.Lock()
		delete(s.devices, deviceID)
		s.mu.Unlock()
		s.broadcastEvent(fmt.Sprintf(`{"event":"device_removed","deviceId":%q}`, deviceID))
		w.WriteHeader(http.StatusNoContent)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleFolders(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.mu.RLock()
		defer s.mu.RUnlock()
		list := make([]interface{}, 0, len(s.folders))
		for _, f := range s.folders {
			list = append(list, f)
		}
		_ = json.NewEncoder(w).Encode(list)

	case http.MethodPost:
		var req struct {
			ID            string   `json:"id"`
			Label         string   `json:"label"`
			Path          string   `json:"path"`
			Type          string   `json:"type"` // sendreceive, sendonly, receiveonly
			SharedDevices []string `json:"sharedDevices"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Path == "" {
			w.WriteHeader(http.StatusBadRequest)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "bad_request", "message": "Missing path"})
			return
		}

		if req.ID == "" {
			req.ID = fmt.Sprintf("folder-%d", time.Now().UnixNano()%1000000)
		}
		if req.Type == "" {
			req.Type = "sendreceive"
		}

		s.mu.Lock()
		folder := map[string]interface{}{
			"id":            req.ID,
			"label":         req.Label,
			"path":          req.Path,
			"type":          req.Type,
			"state":         "idle",
			"paused":        false,
			"sharedDevices": req.SharedDevices,
			"totalBytes":    0,
			"totalFiles":    0,
			"trashCount":    0,
		}
		s.folders[req.ID] = folder
		s.mu.Unlock()

		s.broadcastEvent(fmt.Sprintf(`{"event":"folder_added","folderId":%q}`, req.ID))

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(folder)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleFolderByID(w http.ResponseWriter, r *http.Request) {
	folderID := strings.TrimPrefix(r.URL.Path, "/api/v1/folders/")
	if folderID == "" {
		http.NotFound(w, r)
		return
	}

	switch r.Method {
	case http.MethodGet:
		s.mu.RLock()
		f, exists := s.folders[folderID]
		s.mu.RUnlock()
		if !exists {
			w.WriteHeader(http.StatusNotFound)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "not_found", "message": "Folder not found"})
			return
		}
		_ = json.NewEncoder(w).Encode(f)

	case http.MethodPatch:
		var req struct {
			Paused        *bool    `json:"paused"`
			Type          string   `json:"type"`
			SharedDevices []string `json:"sharedDevices"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		s.mu.Lock()
		f, exists := s.folders[folderID]
		if !exists {
			s.mu.Unlock()
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if req.Paused != nil {
			f["paused"] = *req.Paused
			if *req.Paused {
				f["state"] = "paused"
			} else {
				f["state"] = "idle"
			}
		}
		if req.Type != "" {
			f["type"] = req.Type
		}
		if req.SharedDevices != nil {
			f["sharedDevices"] = req.SharedDevices
		}
		s.mu.Unlock()

		_ = json.NewEncoder(w).Encode(f)

	case http.MethodDelete:
		s.mu.Lock()
		delete(s.folders, folderID)
		s.mu.Unlock()
		s.broadcastEvent(fmt.Sprintf(`{"event":"folder_removed","folderId":%q}`, folderID))
		w.WriteHeader(http.StatusNoContent)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleSend(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		TargetDeviceID string   `json:"targetDeviceId"`
		FilePaths      []string `json:"filePaths"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TargetDeviceID == "" || len(req.FilePaths) == 0 {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "bad_request", "message": "Missing targetDeviceId or filePaths"})
		return
	}

	sessionID := fmt.Sprintf("send-%d", time.Now().UnixNano()%1000000)
	session := map[string]interface{}{
		"sessionId":        sessionID,
		"targetDeviceId":   req.TargetDeviceID,
		"state":            "sending",
		"filesSent":        0,
		"totalFiles":       len(req.FilePaths),
		"bytesSent":        0,
		"totalBytes":       1024 * 1024 * len(req.FilePaths),
		"speedBytesPerSec": 5 * 1024 * 1024,
		"interfaceUsed":    "wifi",
	}

	s.mu.Lock()
	s.sendSessions[sessionID] = session
	s.mu.Unlock()

	s.broadcastEvent(fmt.Sprintf(`{"event":"send_initiated","sessionId":%q}`, sessionID))

	w.WriteHeader(http.StatusAccepted)
	_ = json.NewEncoder(w).Encode(session)
}

func (s *Server) handleSendByID(w http.ResponseWriter, r *http.Request) {
	sessionID := strings.TrimPrefix(r.URL.Path, "/api/v1/send/")
	if sessionID == "" {
		http.NotFound(w, r)
		return
	}

	s.mu.RLock()
	session, exists := s.sendSessions[sessionID]
	s.mu.RUnlock()

	if !exists {
		w.WriteHeader(http.StatusNotFound)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "not_found", "message": "Send session not found"})
		return
	}

	_ = json.NewEncoder(w).Encode(session)
}

func (s *Server) handlePairingCode(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	qrPayload, shortCode, err := s.pairingSvc.GenerateQRPayload("")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]string{
		"deviceId":  s.cfg.DeviceID,
		"name":      s.cfg.DeviceName,
		"qrPayload": qrPayload,
		"shortCode": shortCode,
	})
}

func (s *Server) handlePairingConfirm(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		TargetDeviceID string `json:"targetDeviceId"`
		ConfirmedCode  string `json:"confirmedCode"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	matched := s.pairingSvc.ConfirmPairing(req.TargetDeviceID, req.ConfirmedCode)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"success":  matched,
		"deviceId": req.TargetDeviceID,
	})
}

func (s *Server) handleEventsSSE(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	ch := make(chan string, 10)
	s.mu.Lock()
	s.eventChans[ch] = struct{}{}
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		delete(s.eventChans, ch)
		s.mu.Unlock()
		close(ch)
	}()

	// Send initial ping event
	_, _ = fmt.Fprintf(w, "event: connected\ndata: {\"status\":\"ok\"}\n\n")
	flusher.Flush()

	for {
		select {
		case <-r.Context().Done():
			return
		case msg, ok := <-ch:
			if !ok {
				return
			}
			_, _ = fmt.Fprintf(w, "data: %s\n\n", msg)
			flusher.Flush()
		}
	}
}

func (s *Server) broadcastEvent(data string) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for ch := range s.eventChans {
		select {
		case ch <- data:
		default:
		}
	}
}
