package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"tandem/core/discovery"
	"tandem/core/engine"
	"tandem/core/engine/compat"
	"tandem/core/linkmanager"
	"tandem/core/pal"
	"tandem/core/pairing"
	"tandem/core/send"
	"tandem/core/trash"
)

// ServerConfig configures the local tandemd API server.
type ServerConfig struct {
	BindAddr      string // strictly "127.0.0.1:8385" or loopback
	APIKey        string
	Version       string
	DeviceID      string
	DeviceName    string
	SyncPort      int
	DiscoveryPort int
	ReceiveDir    string
}

type connSample struct {
	at       time.Time
	inBytes  int64
	outBytes int64
	upRate   int64
	downRate int64
}

// Server exposes the localhost REST and Event API for UI clients (Flutter / CLI).
type Server struct {
	cfg            ServerConfig
	palAdapter     pal.Network
	fwAdapter      pal.Firewall
	storageAdapter pal.Storage
	linkMgr        *linkmanager.Manager
	pairingSvc     *pairing.Service
	engine         *engine.SyncthingEngine
	discoverySvc   *discovery.Service
	sendMgr        *send.Manager
	trashMgr       *trash.Manager
	httpServer     *http.Server
	mu             sync.RWMutex
	addr           string
	devices        map[string]map[string]interface{}
	folders        map[string]map[string]interface{}
	sendSessions   map[string]map[string]interface{}
	connSamples    map[string]connSample
	eventChans     map[chan string]struct{}
	lastSTEventID  int64
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
		cfg.Version = "0.3.0"
	}
	if cfg.SyncPort == 0 {
		cfg.SyncPort = 22000
	}
	if cfg.DiscoveryPort == 0 {
		cfg.DiscoveryPort = discovery.DiscoveryPortDefault
	}

	return &Server{
		cfg:          cfg,
		palAdapter:   palAdapter,
		fwAdapter:    fwAdapter,
		linkMgr:      linkMgr,
		pairingSvc:   pairingSvc,
		devices:      make(map[string]map[string]interface{}),
		folders:      make(map[string]map[string]interface{}),
		sendSessions: make(map[string]map[string]interface{}),
		connSamples:  make(map[string]connSample),
		eventChans:   make(map[chan string]struct{}),
		trashMgr:     trash.NewManager(30 * 24 * time.Hour),
	}
}

// AttachRuntime wires real engine, discovery, storage, and send subsystems to the API server.
func (s *Server) AttachRuntime(
	eng *engine.SyncthingEngine,
	disc *discovery.Service,
	storage pal.Storage,
	sendMgr *send.Manager,
) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.engine = eng
	s.discoverySvc = disc
	s.storageAdapter = storage
	s.sendMgr = sendMgr
	if eng != nil && eng.DeviceID() != "" {
		s.cfg.DeviceID = eng.DeviceID()
	}
}

// Start begins listening on the configured loopback address and runs background event watchers.
func (s *Server) Start(ctx context.Context) error {
	mux := http.NewServeMux()

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

	s.mu.Lock()
	s.addr = listener.Addr().String()
	s.mu.Unlock()

	s.httpServer = &http.Server{
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 0, // Streaming SSE requires no write timeout
	}

	if s.engine != nil {
		go s.runEngineEventLoop(ctx)
		go s.runPendingSendAcceptLoop(ctx)
		go s.runConnectionRateLoop(ctx)
	}

	go func() {
		<-ctx.Done()
		_ = s.httpServer.Shutdown(context.Background())
	}()

	return s.httpServer.Serve(listener)
}

func (s *Server) Stop() error {
	if s.httpServer != nil {
		return s.httpServer.Close()
	}
	return nil
}

func (s *Server) Addr() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.addr
}

// RequireAuthForTest exposes requireAuth middleware for black-box security tests.
func (s *Server) RequireAuthForTest(next http.HandlerFunc) http.HandlerFunc {
	return s.requireAuth(next)
}

func (s *Server) requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
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
			if authHeader == token || token != s.cfg.APIKey {
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

// ================= Background Engine Loops =================

func (s *Server) runEngineEventLoop(ctx context.Context) {
	for {
		if ctx.Err() != nil {
			return
		}
		events, err := s.engine.PollEvents(ctx, s.lastSTEventID, 10)
		if err != nil {
			select {
			case <-ctx.Done():
				return
			case <-time.After(500 * time.Millisecond):
			}
			continue
		}
		for _, ev := range events {
			if ev.ID > s.lastSTEventID {
				s.lastSTEventID = ev.ID
			}
			payload, _ := json.Marshal(map[string]any{
				"event": strings.ToLower(ev.Type),
				"type":  ev.Type,
				"data":  ev.Data,
			})
			s.broadcastEvent(string(payload))
		}
	}
}

func (s *Server) runConnectionRateLoop(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			conns, err := s.engine.GetConnections(ctx)
			if err != nil {
				continue
			}
			now := time.Now()
			s.mu.Lock()
			for devID, info := range conns.Connections {
				prev, ok := s.connSamples[devID]
				var upRate, downRate int64
				if ok && now.After(prev.at) {
					dt := now.Sub(prev.at).Seconds()
					if dt > 0 {
						if info.OutBytesTotal >= prev.outBytes {
							upRate = int64(float64(info.OutBytesTotal-prev.outBytes) / dt)
						}
						if info.InBytesTotal >= prev.inBytes {
							downRate = int64(float64(info.InBytesTotal-prev.inBytes) / dt)
						}
					}
				}
				s.connSamples[devID] = connSample{
					at:       now,
					inBytes:  info.InBytesTotal,
					outBytes: info.OutBytesTotal,
					upRate:   upRate,
					downRate: downRate,
				}
			}
			s.mu.Unlock()
		}
	}
}

func (s *Server) runPendingSendAcceptLoop(ctx context.Context) {
	ticker := time.NewTicker(400 * time.Millisecond)
	defer ticker.Stop()

	accepted := make(map[string]string) // folderID -> localPath
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pending, err := s.engine.GetPendingFolders(ctx)
			if err == nil {
				devs, _ := s.engine.GetConfigDevices(ctx)
				trusted := make(map[string]bool)
				for _, d := range devs {
					trusted[d.DeviceID] = true
				}
				existingFolders, _ := s.engine.GetConfigFolders(ctx)
				hasFolder := make(map[string]bool)
				for _, f := range existingFolders {
					hasFolder[f.ID] = true
				}

				for folderID, entry := range pending {
					if !strings.HasPrefix(folderID, "tandem-send-") || hasFolder[folderID] {
						continue
					}
					for devID := range entry.OfferedBy {
						if !trusted[devID] {
							continue
						}
						sessID := strings.TrimPrefix(folderID, "tandem-send-")
						recvBase := s.cfg.ReceiveDir
						if recvBase == "" {
							recvBase = s.engine.Config().ReceiveDir
						}
						destPath := filepath.Join(recvBase, sessID)
						_ = s.engine.UpsertFolder(ctx, engine.FolderConfig{
							ID:      folderID,
							Label:   "Incoming Send " + sessID,
							Path:    destPath,
							Type:    "receiveonly",
							Devices: []engine.FolderDevice{{DeviceID: devID}},
						})
						accepted[folderID] = destPath
						s.broadcastEvent(fmt.Sprintf(`{"event":"send_receiving","sessionId":%q,"fromDeviceId":%q}`, sessID, devID))
						break
					}
				}
			}

			// Clean up Syncthing folder registration after ephemeral send finishes transferring
			for folderID := range accepted {
				st, err := s.engine.GetFolderStatus(ctx, folderID)
				if err != nil {
					delete(accepted, folderID)
					continue
				}
				if st.GlobalFiles > 0 && st.NeedBytes == 0 && st.State == "idle" {
					// Give sender 1s to observe 100% completion before detaching ephemeral folder config
					time.AfterFunc(1500*time.Millisecond, func() {
						_ = s.engine.DeleteFolder(context.Background(), folderID)
					})
					delete(accepted, folderID)
				}
			}
		}
	}
}

// ================= API Handlers =================

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	s.mu.RLock()
	activeTransfers := 0
	for _, sess := range s.sendSessions {
		if sess["state"] == "sending" || sess["state"] == "queued" {
			activeTransfers++
		}
	}
	eng := s.engine
	myID := s.cfg.DeviceID
	s.mu.RUnlock()

	state := "idle"
	if eng != nil {
		if eng.DeviceID() != "" {
			myID = eng.DeviceID()
		}
		if eng.State() != engine.EngineStateRunning {
			state = string(eng.State())
		} else if folders, err := eng.GetConfigFolders(r.Context()); err == nil {
			for _, f := range folders {
				if st, err := eng.GetFolderStatus(r.Context(), f.ID); err == nil {
					if st.State == "syncing" || st.State == "scanning" {
						state = "syncing"
						break
					}
					if st.State == "error" || st.Errors > 0 {
						state = "error"
					}
				}
			}
		}
	}

	hasInternet := false
	if s.palAdapter != nil {
		if ifaces, err := s.palAdapter.Interfaces(); err == nil {
			for _, iface := range ifaces {
				if iface.HasValidatedInternet {
					hasInternet = true
					break
				}
			}
		}
	}

	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"version":         s.cfg.Version,
		"myDeviceId":      myID,
		"myDeviceName":    s.cfg.DeviceName,
		"state":           state,
		"hasInternet":     hasInternet,
		"activeTransfers": activeTransfers,
		"syncPort":        s.cfg.SyncPort,
		"discoveryPort":   s.cfg.DiscoveryPort,
	})
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ports := []pal.Port{
		{Port: s.cfg.SyncPort, Protocol: "tcp"},
		{Port: s.cfg.SyncPort, Protocol: "udp"},
		{Port: s.cfg.DiscoveryPort, Protocol: "udp"},
	}
	fwStatus, _ := s.fwAdapter.Status(ports)
	remediation := s.fwAdapter.Remediation(ports)

	engineReady := true
	syncPortOpen := true
	discoveryWorks := true
	storageOk := true
	inotifyExhausted := false

	if s.engine != nil {
		engineReady = s.engine.Ping(r.Context())
		conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", s.cfg.SyncPort), 500*time.Millisecond)
		if err != nil {
			syncPortOpen = false
		} else {
			_ = conn.Close()
		}
	}

	if s.discoverySvc != nil {
		res := s.discoverySvc.RunSelfTest(r.Context())
		discoveryWorks = res.DiscoveryWorks && s.discoverySvc.IsListening()
	}

	if s.storageAdapter != nil {
		checkPath := "."
		if s.engine != nil {
			checkPath = s.engine.Config().DataDir
		}
		caps := s.storageAdapter.Capabilities(pal.FolderRef{ID: "health", Path: checkPath})
		if !caps.CanWatch && strings.Contains(strings.ToLower(caps.Notes), "inotify") {
			inotifyExhausted = true
		}
	}

	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"engineReady":         engineReady,
		"syncPortOpen":        syncPortOpen,
		"firewallState":       fwStatus,
		"firewallRemediation": remediation.Description,
		"firewallCommand":     remediation.Command,
		"discoveryWorks":      discoveryWorks,
		"storageOk":           storageOk,
		"inotifyExhausted":    inotifyExhausted,
		"batteryOptimized":    false,
	})
}

func classifyConnection(devID string, conn engine.ConnectionInfo) linkmanager.LinkState {
	if !conn.Connected {
		return linkmanager.LinkStateOffline
	}
	t := strings.ToLower(conn.Type)
	if strings.Contains(t, "relay") {
		return linkmanager.LinkStateRelayed
	}
	if conn.IsLocal {
		return linkmanager.LinkStateDirectLocal
	}
	return linkmanager.ClassifyAddress(conn.Address, true)
}

func (s *Server) handleDevices(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		if s.engine == nil {
			s.mu.RLock()
			list := make([]interface{}, 0, len(s.devices))
			for _, dev := range s.devices {
				list = append(list, dev)
			}
			s.mu.RUnlock()
			_ = json.NewEncoder(w).Encode(list)
			return
		}

		myID := s.engine.DeviceID()
		cfgDevs, err := s.engine.GetConfigDevices(r.Context())
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "engine_error", "message": err.Error()})
			return
		}
		conns, _ := s.engine.GetConnections(r.Context())

		pairedSet := make(map[string]bool)
		list := make([]map[string]interface{}, 0, len(cfgDevs))

		for _, dev := range cfgDevs {
			if dev.DeviceID == myID {
				continue
			}
			pairedSet[dev.DeviceID] = true
			linkState := linkmanager.LinkStateOffline
			var activeAddrs []string
			activeAddrs = append(activeAddrs, dev.Addresses...)
			lastSeen := ""
			var upRate, downRate int64

			if conns != nil {
				if cInfo, ok := conns.Connections[dev.DeviceID]; ok {
					linkState = classifyConnection(dev.DeviceID, cInfo)
					if cInfo.Address != "" {
						activeAddrs = []string{cInfo.Address}
					}
					if cInfo.At != "" && !strings.HasPrefix(cInfo.At, "0001-01-01") {
						lastSeen = cInfo.At
					}
				}
			}
			s.mu.RLock()
			if sample, ok := s.connSamples[dev.DeviceID]; ok {
				upRate = sample.upRate
				downRate = sample.downRate
			}
			s.mu.RUnlock()

			list = append(list, map[string]interface{}{
				"id":                    dev.DeviceID,
				"name":                  dev.Name,
				"isPaired":              true,
				"linkState":             linkState,
				"lastSeen":              lastSeen,
				"addresses":             activeAddrs,
				"uploadRateBytesPerSec": upRate,
				"downloadRateBytesPerSec": downRate,
			})
		}

		if s.discoverySvc != nil {
			for _, peer := range s.discoverySvc.DiscoveredPeers() {
				if peer.DeviceID == myID || pairedSet[peer.DeviceID] {
					continue
				}
				list = append(list, map[string]interface{}{
					"id":                    peer.DeviceID,
					"name":                  peer.DeviceName,
					"isPaired":              false,
					"linkState":             linkmanager.LinkStateDirectLocal,
					"lastSeen":              peer.LastSeen.Format(time.RFC3339),
					"addresses":             peer.Addresses,
					"uploadRateBytesPerSec": int64(0),
					"downloadRateBytesPerSec": int64(0),
				})
			}
		}

		sort.Slice(list, func(i, j int) bool {
			return fmt.Sprint(list[i]["id"]) < fmt.Sprint(list[j]["id"])
		})
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

		if s.engine == nil {
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
			return
		}

		addrs := []string{"dynamic"}
		if req.AddressHint != "" {
			addrs = []string{req.AddressHint, "dynamic"}
		} else if s.discoverySvc != nil {
			for _, peer := range s.discoverySvc.DiscoveredPeers() {
				if peer.DeviceID == req.DeviceID && len(peer.Addresses) > 0 {
					addrs = append(peer.Addresses, "dynamic")
					if req.Name == "" {
						req.Name = peer.DeviceName
					}
					break
				}
			}
		}

		if req.Name == "" {
			req.Name = req.DeviceID[:min(8, len(req.DeviceID))]
		}

		if err := s.engine.UpsertDevice(r.Context(), engine.DeviceConfig{
			DeviceID:  req.DeviceID,
			Name:      req.Name,
			Addresses: addrs,
		}); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "engine_error", "message": err.Error()})
			return
		}

		s.broadcastEvent(fmt.Sprintf(`{"event":"device_paired","deviceId":%q}`, req.DeviceID))
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"id":        req.DeviceID,
			"name":      req.Name,
			"isPaired":  true,
			"linkState": linkmanager.LinkStateConnecting,
			"lastSeen":  time.Now().Format(time.RFC3339),
			"addresses": addrs,
		})

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

	if s.engine == nil {
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
		return
	}

	switch r.Method {
	case http.MethodGet:
		devs, err := s.engine.GetConfigDevices(r.Context())
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		conns, _ := s.engine.GetConnections(r.Context())
		for _, dev := range devs {
			if dev.DeviceID == deviceID {
				linkState := linkmanager.LinkStateOffline
				if conns != nil {
					if cInfo, ok := conns.Connections[dev.DeviceID]; ok {
						linkState = classifyConnection(dev.DeviceID, cInfo)
					}
				}
				_ = json.NewEncoder(w).Encode(map[string]interface{}{
					"id":        dev.DeviceID,
					"name":      dev.Name,
					"isPaired":  true,
					"linkState": linkState,
					"addresses": dev.Addresses,
				})
				return
			}
		}
		w.WriteHeader(http.StatusNotFound)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "not_found", "message": "Device not found"})

	case http.MethodDelete:
		if err := s.engine.DeleteDevice(r.Context(), deviceID); err != nil {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		s.broadcastEvent(fmt.Sprintf(`{"event":"device_removed","deviceId":%q}`, deviceID))
		w.WriteHeader(http.StatusNoContent)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) buildFolderDTO(ctx context.Context, f engine.FolderConfig) map[string]interface{} {
	st, err := s.engine.GetFolderStatus(ctx, f.ID)
	state := "idle"
	if f.Paused {
		state = "paused"
	}
	var totalBytes, needBytes int64
	var totalFiles int
	if err == nil && st != nil {
		totalBytes = st.LocalBytes
		if st.GlobalBytes > totalBytes {
			totalBytes = st.GlobalBytes
		}
		totalFiles = st.LocalFiles
		if st.GlobalFiles > totalFiles {
			totalFiles = st.GlobalFiles
		}
		needBytes = st.NeedBytes
		if !f.Paused && st.State != "" {
			state = st.State
		}
		if st.Errors > 0 || st.PullErrors > 0 || st.Invalid != "" {
			state = "error"
		}
	}

	myID := s.engine.DeviceID()
	shared := make([]string, 0, len(f.Devices))
	for _, d := range f.Devices {
		if d.DeviceID != myID {
			shared = append(shared, d.DeviceID)
		}
	}

	trashItems := s.scanTrashItems(f.Path)

	return map[string]interface{}{
		"id":            f.ID,
		"label":         f.Label,
		"path":          f.Path,
		"type":          f.Type,
		"state":         state,
		"paused":        f.Paused,
		"sharedDevices": shared,
		"totalBytes":    totalBytes,
		"totalFiles":    totalFiles,
		"needBytes":     needBytes,
		"trashCount":    len(trashItems),
	}
}

func (s *Server) handleFolders(w http.ResponseWriter, r *http.Request) {
	if s.engine == nil {
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
				Type          string   `json:"type"`
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
		return
	}

	switch r.Method {
	case http.MethodGet:
		cfgFolders, err := s.engine.GetConfigFolders(r.Context())
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "engine_error", "message": err.Error()})
			return
		}
		list := make([]map[string]interface{}, 0, len(cfgFolders))
		for _, f := range cfgFolders {
			if strings.HasPrefix(f.ID, "tandem-send-") {
				continue
			}
			list = append(list, s.buildFolderDTO(r.Context(), f))
		}
		_ = json.NewEncoder(w).Encode(list)

	case http.MethodPost:
		var req struct {
			ID            string   `json:"id"`
			Label         string   `json:"label"`
			Path          string   `json:"path"`
			Type          string   `json:"type"`
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
		if req.Label == "" {
			req.Label = filepath.Base(req.Path)
		}
		if req.Type == "" {
			req.Type = "sendreceive"
		}
		devs := make([]engine.FolderDevice, 0, len(req.SharedDevices))
		for _, d := range req.SharedDevices {
			devs = append(devs, engine.FolderDevice{DeviceID: d})
		}

		fCfg := engine.FolderConfig{
			ID:      req.ID,
			Label:   req.Label,
			Path:    req.Path,
			Type:    req.Type,
			Devices: devs,
		}
		if err := s.engine.UpsertFolder(r.Context(), fCfg); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "engine_error", "message": err.Error()})
			return
		}
		_ = s.engine.RescanFolder(r.Context(), req.ID)
		s.broadcastEvent(fmt.Sprintf(`{"event":"folder_added","folderId":%q}`, req.ID))

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(s.buildFolderDTO(r.Context(), fCfg))

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleFolderByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/folders/")
	if rest == "" {
		http.NotFound(w, r)
		return
	}

	parts := strings.Split(rest, "/")
	folderID := parts[0]
	sub := ""
	if len(parts) > 1 {
		sub = strings.Join(parts[1:], "/")
	}

	if s.engine == nil {
		switch r.Method {
		case http.MethodGet:
			if sub == "errors" || sub == "trash" {
				_ = json.NewEncoder(w).Encode([]interface{}{})
				return
			}
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
		return
	}

	fCfg, err := s.engine.GetConfigFolder(r.Context(), folderID)
	if err != nil {
		w.WriteHeader(http.StatusNotFound)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "not_found", "message": "Folder not found"})
		return
	}

	switch sub {
	case "errors":
		s.handleFolderErrors(w, r, fCfg)
		return
	case "trash":
		s.handleFolderTrashList(w, r, fCfg)
		return
	case "trash/restore":
		s.handleFolderTrashRestore(w, r, fCfg)
		return
	}

	switch r.Method {
	case http.MethodGet:
		_ = json.NewEncoder(w).Encode(s.buildFolderDTO(r.Context(), *fCfg))

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
		if req.Paused != nil {
			fCfg.Paused = *req.Paused
		}
		if req.Type != "" {
			fCfg.Type = req.Type
		}
		if req.SharedDevices != nil {
			devs := make([]engine.FolderDevice, 0, len(req.SharedDevices))
			for _, id := range req.SharedDevices {
				devs = append(devs, engine.FolderDevice{DeviceID: id})
			}
			fCfg.Devices = devs
		}
		if err := s.engine.UpsertFolder(r.Context(), *fCfg); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(s.buildFolderDTO(r.Context(), *fCfg))

	case http.MethodDelete:
		if err := s.engine.DeleteFolder(r.Context(), folderID); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		s.broadcastEvent(fmt.Sprintf(`{"event":"folder_removed","folderId":%q}`, folderID))
		w.WriteHeader(http.StatusNoContent)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleFolderErrors(w http.ResponseWriter, r *http.Request, fCfg *engine.FolderConfig) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var out []map[string]interface{}

	// 1. Syncthing folder errors & disk-full status
	if st, err := s.engine.GetFolderStatus(r.Context(), fCfg.ID); err == nil && st != nil {
		for _, rawMsg := range []string{st.Error, st.Invalid} {
			if rawMsg == "" {
				continue
			}
			low := strings.ToLower(rawMsg)
			code := "folder_error"
			if strings.Contains(low, "space") || strings.Contains(low, "enospc") || strings.Contains(low, "disk") {
				code = "err.disk_full"
			}
			out = append(out, map[string]interface{}{
				"code":    code,
				"path":    fCfg.Path,
				"message": rawMsg,
			})
		}
	}
	if fe, err := s.engine.GetFolderErrors(r.Context(), fCfg.ID); err == nil && fe != nil {
		for _, item := range fe.Errors {
			msgLow := strings.ToLower(item.Error)
			code := "pull_error"
			if strings.Contains(msgLow, "space") || strings.Contains(msgLow, "enospc") || strings.Contains(msgLow, "disk") {
				code = "err.disk_full"
			}
			out = append(out, map[string]interface{}{
				"code":    code,
				"path":    item.Path,
				"message": item.Error,
			})
		}
	}

	// 2. Cross-OS filename compatibility warnings (case collisions & Windows reserved names)
	var allNames []string
	_ = filepath.Walk(fCfg.Path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		rel, _ := filepath.Rel(fCfg.Path, path)
		if rel == "." {
			return nil
		}
		if strings.HasPrefix(rel, ".st") || strings.HasPrefix(rel, ".tandem-trash") {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if info.IsDir() {
			return nil
		}
		allNames = append(allNames, rel)
		if cType, msg := compat.CheckNameCompatibility(filepath.Base(path), "windows"); cType != compat.ConflictNone {
			out = append(out, map[string]interface{}{
				"code":    string(cType),
				"path":    rel,
				"message": msg,
			})
		}
		if strings.Contains(filepath.Base(path), ".sync-conflict-") {
			out = append(out, map[string]interface{}{
				"code":    "conflict.both_changed",
				"path":    rel,
				"message": fmt.Sprintf("Both devices changed %q; Tandem preserved conflict copy.", filepath.Base(path)),
			})
		}
		return nil
	})
	for key, collList := range compat.DetectCaseCollisions(allNames) {
		out = append(out, map[string]interface{}{
			"code":    string(compat.ConflictCaseCollision),
			"path":    strings.Join(collList, ", "),
			"message": fmt.Sprintf("Case collision (%s): %v can't both exist on Windows or macOS.", key, collList),
		})
	}

	if out == nil {
		out = []map[string]interface{}{}
	}
	_ = json.NewEncoder(w).Encode(out)
}

var syncthingVersionSuffixRe = regexp.MustCompile(`~(\d{8}-\d{6})(\.[^.]+)?$`)

func stripVersionSuffix(rel string) string {
	dir := filepath.Dir(rel)
	base := filepath.Base(rel)
	clean := syncthingVersionSuffixRe.ReplaceAllString(base, "$2")
	if dir == "." {
		return clean
	}
	return filepath.Join(dir, clean)
}

func (s *Server) scanTrashItems(folderPath string) []trash.TrashItem {
	trashRoot := filepath.Join(folderPath, trash.TrashDirName)
	var items []trash.TrashItem
	_ = filepath.Walk(trashRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(trashRoot, path)
		if err != nil || rel == trash.ManifestFileName {
			return nil
		}
		items = append(items, trash.TrashItem{
			TrashID:      filepath.ToSlash(rel),
			OriginalPath: filepath.ToSlash(stripVersionSuffix(rel)),
			DeletedAt:    info.ModTime().UTC(),
			SizeBytes:    info.Size(),
		})
		return nil
	})
	return items
}

func (s *Server) handleFolderTrashList(w http.ResponseWriter, r *http.Request, fCfg *engine.FolderConfig) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	items := s.scanTrashItems(fCfg.Path)
	if items == nil {
		items = []trash.TrashItem{}
	}
	_ = json.NewEncoder(w).Encode(items)
}

func (s *Server) handleFolderTrashRestore(w http.ResponseWriter, r *http.Request, fCfg *engine.FolderConfig) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		TrashID string `json:"trashId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TrashID == "" {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "bad_request", "message": "Missing trashId"})
		return
	}

	trashRoot := filepath.Join(fCfg.Path, trash.TrashDirName)
	srcPath, err := compat.SafePath(trashRoot, filepath.FromSlash(req.TrashID))
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "invalid_path", "message": err.Error()})
		return
	}
	if _, err := os.Stat(srcPath); err != nil {
		w.WriteHeader(http.StatusNotFound)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "not_found", "message": "Trash item not found"})
		return
	}

	origRel := stripVersionSuffix(filepath.FromSlash(req.TrashID))
	destPath, err := compat.SafePath(fCfg.Path, origRel)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "invalid_path", "message": err.Error()})
		return
	}

	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	if err := os.Rename(srcPath, destPath); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{"code": "restore_failed", "message": err.Error()})
		return
	}

	_ = s.engine.RescanFolder(r.Context(), fCfg.ID)
	s.broadcastEvent(fmt.Sprintf(`{"event":"trash_restored","folderId":%q,"path":%q}`, fCfg.ID, filepath.ToSlash(origRel)))

	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"restored": true,
		"path":     filepath.ToSlash(origRel),
	})
}

func (s *Server) handleSend(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.mu.RLock()
		list := make([]map[string]interface{}, 0, len(s.sendSessions))
		for _, sess := range s.sendSessions {
			list = append(list, sess)
		}
		s.mu.RUnlock()
		_ = json.NewEncoder(w).Encode(list)
		return

	case http.MethodPost:
		var req struct {
			TargetDeviceID string   `json:"targetDeviceId"`
			FilePaths      []string `json:"filePaths"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TargetDeviceID == "" || len(req.FilePaths) == 0 {
			w.WriteHeader(http.StatusBadRequest)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "bad_request", "message": "Missing targetDeviceId or filePaths"})
			return
		}

		if s.engine == nil || s.sendMgr == nil {
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
			return
		}

		sess, err := s.sendMgr.CreateSession(req.TargetDeviceID, req.FilePaths)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "bad_request", "message": err.Error()})
			return
		}

		folderID := "tandem-send-" + sess.SessionID
		if err := s.engine.UpsertFolder(r.Context(), engine.FolderConfig{
			ID:      folderID,
			Label:   "Send " + sess.SessionID,
			Path:    sess.EphemeralFolder,
			Type:    "sendonly",
			Devices: []engine.FolderDevice{{DeviceID: req.TargetDeviceID}},
		}); err != nil {
			_ = os.RemoveAll(sess.EphemeralFolder)
			w.WriteHeader(http.StatusInternalServerError)
			_ = json.NewEncoder(w).Encode(map[string]string{"code": "engine_error", "message": err.Error()})
			return
		}
		_ = s.engine.RescanFolder(r.Context(), folderID)

		sessDTO := map[string]interface{}{
			"sessionId":        sess.SessionID,
			"targetDeviceId":   sess.TargetDeviceID,
			"state":            "sending",
			"filesSent":        0,
			"totalFiles":       sess.TotalFiles,
			"bytesSent":        int64(0),
			"totalBytes":       sess.TotalBytes,
			"speedBytesPerSec": int64(0),
			"interfaceUsed":    string(linkmanager.LinkStateConnecting),
		}
		s.mu.Lock()
		s.sendSessions[sess.SessionID] = sessDTO
		s.mu.Unlock()

		s.broadcastEvent(fmt.Sprintf(`{"event":"send_initiated","sessionId":%q}`, sess.SessionID))
		go s.trackSendSession(sess.SessionID, folderID, req.TargetDeviceID, sess.TotalFiles, sess.TotalBytes, sess.EphemeralFolder)

		w.WriteHeader(http.StatusAccepted)
		_ = json.NewEncoder(w).Encode(sessDTO)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) trackSendSession(sessionID, folderID, targetDeviceID string, totalFiles int, totalBytes int64, ephemeralDir string) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			comp, err := s.engine.GetCompletion(ctx, folderID, targetDeviceID)
			if err != nil {
				continue
			}

			var speed int64
			iface := string(linkmanager.LinkStateConnecting)
			if conns, err := s.engine.GetConnections(ctx); err == nil {
				if cInfo, ok := conns.Connections[targetDeviceID]; ok {
					iface = string(classifyConnection(targetDeviceID, cInfo))
				}
			}
			s.mu.RLock()
			if sample, ok := s.connSamples[targetDeviceID]; ok {
				speed = sample.upRate
			}
			s.mu.RUnlock()

			bytesSent := int64(float64(totalBytes) * (comp.Completion / 100.0))
			filesSent := int(float64(totalFiles) * (comp.Completion / 100.0))

			s.mu.Lock()
			if dto, ok := s.sendSessions[sessionID]; ok {
				dto["bytesSent"] = bytesSent
				dto["filesSent"] = filesSent
				dto["speedBytesPerSec"] = speed
				dto["interfaceUsed"] = iface
				if comp.GlobalBytes > 0 && comp.NeedBytes == 0 && comp.Completion >= 100.0 {
					dto["state"] = "completed"
					dto["bytesSent"] = totalBytes
					dto["filesSent"] = totalFiles
					s.mu.Unlock()
					_ = s.engine.DeleteFolder(context.Background(), folderID)
					_ = s.sendMgr.CompleteSession(sessionID)
					s.broadcastEvent(fmt.Sprintf(`{"event":"send_completed","sessionId":%q}`, sessionID))
					return
				}
			}
			s.mu.Unlock()
		}
	}
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

	var addrHint string
	if s.palAdapter != nil {
		if ifaces, err := s.palAdapter.Interfaces(); err == nil {
			for _, iface := range ifaces {
				if iface.IsLocalOnly {
					continue
				}
				for _, a := range iface.Addrs {
					if ipnet, ok := a.(*net.IPNet); ok && ipnet.IP.To4() != nil {
						addrHint = fmt.Sprintf("tcp://%s:%d", ipnet.IP.String(), s.cfg.SyncPort)
						break
					}
				}
				if addrHint != "" {
					break
				}
			}
		}
	}

	qrPayload, shortCode, err := s.pairingSvc.GenerateQRPayload(addrHint)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	myID := s.cfg.DeviceID
	if s.engine != nil && s.engine.DeviceID() != "" {
		myID = s.engine.DeviceID()
	}

	_ = json.NewEncoder(w).Encode(map[string]string{
		"deviceId":  myID,
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
		Name           string `json:"name"`
		AddressHint    string `json:"addressHint"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	matched := s.pairingSvc.ConfirmPairing(req.TargetDeviceID, req.ConfirmedCode)
	if matched && s.engine != nil && req.TargetDeviceID != "" {
		addrs := []string{"dynamic"}
		if req.AddressHint != "" {
			addrs = []string{req.AddressHint, "dynamic"}
		} else if s.discoverySvc != nil {
			for _, p := range s.discoverySvc.DiscoveredPeers() {
				if p.DeviceID == req.TargetDeviceID && len(p.Addresses) > 0 {
					addrs = append(p.Addresses, "dynamic")
					if req.Name == "" {
						req.Name = p.DeviceName
					}
					break
				}
			}
		}
		if req.Name == "" {
			req.Name = req.TargetDeviceID[:min(8, len(req.TargetDeviceID))]
		}
		_ = s.engine.UpsertDevice(r.Context(), engine.DeviceConfig{
			DeviceID:  req.TargetDeviceID,
			Name:      req.Name,
			Addresses: addrs,
		})
		s.broadcastEvent(fmt.Sprintf(`{"event":"device_paired","deviceId":%q}`, req.TargetDeviceID))
	}

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

	ch := make(chan string, 32)
	s.mu.Lock()
	s.eventChans[ch] = struct{}{}
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		delete(s.eventChans, ch)
		s.mu.Unlock()
		close(ch)
	}()

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

// Unused io import guard if needed in future handlers
var _ = io.EOF
