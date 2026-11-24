package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"tandem/core/api"
	"tandem/core/linkmanager"
	"tandem/core/pal_linux"
	"tandem/core/pairing"
)

func setupTestServer(t *testing.T) (*api.Server, string) {
	linuxPal := pal_linux.NewLinuxAdapter()
	linkMgr := linkmanager.NewManager()
	pairingSvc := pairing.NewService("TEST-DEV-ID-A", "Test Laptop")

	apiKey := "test-secret-token-12345"
	cfg := api.ServerConfig{
		BindAddr:   "127.0.0.1:0", // random dynamic loopback port
		APIKey:     apiKey,
		Version:    "0.1.0-test",
		DeviceID:   "TEST-DEV-ID-A",
		DeviceName: "Test Laptop",
	}

	server := api.NewServer(cfg, linuxPal, linuxPal, linkMgr, pairingSvc)
	return server, apiKey
}

func TestLocalAPIEndpoints(t *testing.T) {
	linuxPal := pal_linux.NewLinuxAdapter()
	linkMgr := linkmanager.NewManager()
	pairingSvc := pairing.NewService("TEST-DEV-ID-A", "Test Laptop")

	apiKey := "test-token"
	bindAddr := "127.0.0.1:9385"
	cfg := api.ServerConfig{
		BindAddr:   bindAddr,
		APIKey:     apiKey,
		Version:    "0.1.0-test",
		DeviceID:   "TEST-DEV-ID-A",
		DeviceName: "Test Laptop",
	}

	server := api.NewServer(cfg, linuxPal, linuxPal, linkMgr, pairingSvc)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		_ = server.Start(ctx)
	}()

	// Wait for server to be ready
	time.Sleep(100 * time.Millisecond)

	baseURL := "http://" + bindAddr + "/api/v1"
	client := &http.Client{Timeout: 2 * time.Second}

	// 1. Test unauthorized request
	t.Run("AuthRequired", func(t *testing.T) {
		req, _ := http.NewRequest(http.MethodGet, baseURL+"/status", nil)
		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("expected 401 Unauthorized, got: %d", resp.StatusCode)
		}
	})

	// Helper for authenticated requests
	doAuth := func(method, path string, body []byte) *http.Response {
		req, _ := http.NewRequest(method, baseURL+path, bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+apiKey)
		req.Header.Set("Content-Type", "application/json")
		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("auth request failed: %v", err)
		}
		return resp
	}

	// 2. Test /status
	t.Run("GetStatus", func(t *testing.T) {
		resp := doAuth(http.MethodGet, "/status", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got: %d", resp.StatusCode)
		}
		var res map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&res)
		if res["myDeviceId"] != "TEST-DEV-ID-A" {
			t.Errorf("expected deviceId TEST-DEV-ID-A, got: %v", res["myDeviceId"])
		}
	})

	// 3. Test /health
	t.Run("GetHealth", func(t *testing.T) {
		resp := doAuth(http.MethodGet, "/health", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got: %d", resp.StatusCode)
		}
		var res map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&res)
		if res["discoveryWorks"] != true {
			t.Errorf("expected discoveryWorks true, got: %v", res["discoveryWorks"])
		}
	})

	// 4. Test /devices (Pairing & List)
	t.Run("DevicesCRUD", func(t *testing.T) {
		pairPayload := `{"deviceId":"REMOTE-DEV-B","name":"Phone","addressHint":"192.168.1.100:22000"}`
		resp := doAuth(http.MethodPost, "/devices", []byte(pairPayload))
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected 201 Created, got: %d", resp.StatusCode)
		}
		resp.Body.Close()

		// List devices
		resp = doAuth(http.MethodGet, "/devices", nil)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got: %d", resp.StatusCode)
		}
		var list []map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&list)
		resp.Body.Close()

		if len(list) != 1 || list[0]["id"] != "REMOTE-DEV-B" {
			t.Errorf("devices list mismatch: %v", list)
		}

		// Delete device
		resp = doAuth(http.MethodDelete, "/devices/REMOTE-DEV-B", nil)
		if resp.StatusCode != http.StatusNoContent {
			t.Errorf("expected 204 NoContent, got: %d", resp.StatusCode)
		}
		resp.Body.Close()
	})

	// 5. Test /folders
	t.Run("FoldersCRUD", func(t *testing.T) {
		folderPayload := `{"id":"photos","label":"Photos","path":"/home/user/Photos","type":"sendreceive"}`
		resp := doAuth(http.MethodPost, "/folders", []byte(folderPayload))
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected 201 Created, got: %d", resp.StatusCode)
		}
		resp.Body.Close()

		// List folders
		resp = doAuth(http.MethodGet, "/folders", nil)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got: %d", resp.StatusCode)
		}
		var list []map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&list)
		resp.Body.Close()

		if len(list) != 1 || list[0]["id"] != "photos" {
			t.Errorf("folder list mismatch: %v", list)
		}

		// Delete folder
		resp = doAuth(http.MethodDelete, "/folders/photos", nil)
		if resp.StatusCode != http.StatusNoContent {
			t.Errorf("expected 204 NoContent, got: %d", resp.StatusCode)
		}
		resp.Body.Close()
	})

	// 6. Test /pairing/code & /pairing/confirm
	t.Run("PairingFlow", func(t *testing.T) {
		resp := doAuth(http.MethodGet, "/pairing/code", nil)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got: %d", resp.StatusCode)
		}
		var pairInfo map[string]string
		_ = json.NewDecoder(resp.Body).Decode(&pairInfo)
		resp.Body.Close()

		if pairInfo["qrPayload"] == "" || pairInfo["shortCode"] == "" {
			t.Errorf("missing qrPayload or shortCode in response: %v", pairInfo)
		}

		// Confirm match with correct derived code
		targetID := "REMOTE-PHONE-X"
		expectedCode := pairing.DeriveShortCode("TEST-DEV-ID-A", targetID)
		confirmPayload := `{"targetDeviceId":"` + targetID + `","confirmedCode":"` + expectedCode + `"}`

		resp = doAuth(http.MethodPost, "/pairing/confirm", []byte(confirmPayload))
		var confirmResult map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&confirmResult)
		resp.Body.Close()

		if confirmResult["success"] != true {
			t.Errorf("expected pairing confirmation success true, got: %v", confirmResult)
		}
	})

	// 7. Test /send session initiation
	t.Run("SendSession", func(t *testing.T) {
		sendPayload := `{"targetDeviceId":"REMOTE-DEV-B","filePaths":["/tmp/photo1.jpg","/tmp/photo2.jpg"]}`
		resp := doAuth(http.MethodPost, "/send", []byte(sendPayload))
		if resp.StatusCode != http.StatusAccepted {
			t.Fatalf("expected 202 Accepted, got: %d", resp.StatusCode)
		}
		var session map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&session)
		resp.Body.Close()

		if session["sessionId"] == "" || session["state"] != "sending" {
			t.Errorf("invalid send session output: %v", session)
		}
	})
}
