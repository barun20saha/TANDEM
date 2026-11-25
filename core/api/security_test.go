package api_test

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"tandem/core/api"
	"tandem/core/linkmanager"
	"tandem/core/pal_linux"
	"tandem/core/pairing"
)

func TestSecurity_LoopbackOnlyAndPairingConfirmationGate(t *testing.T) {
	linuxPal := pal_linux.NewLinuxAdapter()
	linkMgr := linkmanager.NewManager()
	pairingSvc := pairing.NewService("SEC-LOCAL-ID", "SecHost")
	srv := api.NewServer(api.ServerConfig{
		BindAddr:   "127.0.0.1:0",
		APIKey:     "sec-key-123",
		Version:    "0.3.0-test",
		DeviceID:   "SEC-LOCAL-ID",
		DeviceName: "SecHost",
	}, linuxPal, linuxPal, linkMgr, pairingSvc)

	// Verify pairing rejects mismatched verification codes
	if pairingSvc.ConfirmPairing("UNTRUSTED-PEER", "000000") {
		t.Fatalf("expected mismatched pairing code to be rejected")
	}

	// Verify non-loopback RemoteAddr cannot call protected handlers
	req := httptest.NewRequest(http.MethodGet, "/api/v1/status", nil)
	req.RemoteAddr = "192.168.1.55:54321"
	req.Header.Set("Authorization", "Bearer sec-key-123")
	rec := httptest.NewRecorder()
	srv.RequireAuthForTest(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 Forbidden for non-loopback client, got %d", rec.Code)
	}

	// Loopback with valid token succeeds
	req2 := httptest.NewRequest(http.MethodPost, "/api/v1/pairing/confirm", bytes.NewReader([]byte(`{"targetDeviceId":"PEER-X","confirmedCode":"000000"}`)))
	req2.RemoteAddr = "127.0.0.1:54321"
	req2.Header.Set("Authorization", "Bearer sec-key-123")
	rec2 := httptest.NewRecorder()
	srv.RequireAuthForTest(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})(rec2, req2)
	if rec2.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for loopback with valid token, got %d", rec2.Code)
	}
}
