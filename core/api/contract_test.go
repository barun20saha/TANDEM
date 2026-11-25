package api_test

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"tandem/core/api"
	"tandem/core/linkmanager"
	"tandem/core/pal_linux"
	"tandem/core/pairing"
)

type openAPISpec struct {
	Paths   map[string][]string
	Schemas map[string]schemaSpec
}

type schemaSpec struct {
	Required []string
	Enums    map[string][]string
}

// parseOpenAPI extracts every documented path, HTTP method, required field, and enum
// directly from docs/openapi.yaml without external dependencies.
func parseOpenAPI(t *testing.T, yamlPath string) openAPISpec {
	t.Helper()
	f, err := os.Open(yamlPath)
	if err != nil {
		t.Fatalf("open %s: %v", yamlPath, err)
	}
	defer f.Close()

	spec := openAPISpec{
		Paths:   make(map[string][]string),
		Schemas: make(map[string]schemaSpec),
	}

	section := ""
	currentPath := ""
	currentSchema := ""
	inRequired := false
	currentProp := ""
	enumRe := regexp.MustCompile(`enum:\s*\[([^\]]+)\]`)

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		indent := len(line) - len(strings.TrimLeft(line, " "))

		if indent == 0 {
			inRequired = false
			currentPath = ""
			currentSchema = ""
			switch {
			case strings.HasPrefix(trimmed, "paths:"):
				section = "paths"
			case strings.HasPrefix(trimmed, "components:"):
				section = "components"
			default:
				section = ""
			}
			continue
		}

		if section == "paths" {
			if indent == 2 && strings.HasPrefix(trimmed, "/") && strings.HasSuffix(trimmed, ":") {
				currentPath = strings.TrimSuffix(trimmed, ":")
				continue
			}
			if indent == 4 && currentPath != "" && strings.HasSuffix(trimmed, ":") {
				method := strings.ToUpper(strings.TrimSuffix(trimmed, ":"))
				switch method {
				case "GET", "POST", "PATCH", "PUT", "DELETE":
					spec.Paths[currentPath] = append(spec.Paths[currentPath], method)
				}
			}
		}

		if section == "components" {
			if indent == 2 && trimmed == "schemas:" {
				continue
			}
			if indent == 4 && strings.HasSuffix(trimmed, ":") {
				currentSchema = strings.TrimSuffix(trimmed, ":")
				if _, ok := spec.Schemas[currentSchema]; !ok {
					spec.Schemas[currentSchema] = schemaSpec{
						Enums: make(map[string][]string),
					}
				}
				inRequired = false
				currentProp = ""
				continue
			}
			if currentSchema != "" {
				if indent == 6 && trimmed == "required:" {
					inRequired = true
					continue
				}
				if indent <= 6 && trimmed != "required:" {
					inRequired = false
				}
				if inRequired && indent == 8 && strings.HasPrefix(trimmed, "- ") {
					field := strings.TrimSpace(strings.TrimPrefix(trimmed, "- "))
					s := spec.Schemas[currentSchema]
					s.Required = append(s.Required, field)
					spec.Schemas[currentSchema] = s
					continue
				}
				if indent == 8 && strings.HasSuffix(trimmed, ":") {
					currentProp = strings.TrimSuffix(trimmed, ":")
					continue
				}
				if indent >= 10 && currentProp != "" {
					if m := enumRe.FindStringSubmatch(trimmed); len(m) == 2 {
						var vals []string
						for _, part := range strings.Split(m[1], ",") {
							vals = append(vals, strings.TrimSpace(part))
						}
						s := spec.Schemas[currentSchema]
						s.Enums[currentProp] = vals
						spec.Schemas[currentSchema] = s
					}
				}
			}
		}
	}
	if err := sc.Err(); err != nil {
		t.Fatalf("scan %s: %v", yamlPath, err)
	}
	return spec
}

func assertSchema(t *testing.T, spec openAPISpec, schemaName string, obj map[string]any) {
	t.Helper()
	sc, ok := spec.Schemas[schemaName]
	if !ok {
		t.Fatalf("schema %q not found in openapi.yaml", schemaName)
	}
	for _, req := range sc.Required {
		if _, exists := obj[req]; !exists {
			t.Errorf("schema %s missing required field %q in payload %v", schemaName, req, obj)
		}
	}
	for prop, allowed := range sc.Enums {
		if raw, exists := obj[prop]; exists {
			val, _ := raw.(string)
			found := false
			for _, a := range allowed {
				if val == a {
					found = true
					break
				}
			}
			if !found {
				t.Errorf("schema %s field %q=%q not in enum %v", schemaName, prop, val, allowed)
			}
		}
	}
}

func TestOpenAPIContractAndAuthParity(t *testing.T) {
	specPath := filepath.Clean("../../docs/openapi.yaml")
	spec := parseOpenAPI(t, specPath)
	if len(spec.Paths) < 10 {
		t.Fatalf("expected >= 10 paths parsed from openapi.yaml, got %d", len(spec.Paths))
	}

	linuxPal := pal_linux.NewLinuxAdapter()
	linkMgr := linkmanager.NewManager()
	pairingSvc := pairing.NewService("CONTRACT-DEV-A", "ContractHost")
	apiKey := "contract-secret-token"
	server := api.NewServer(api.ServerConfig{
		BindAddr:   "127.0.0.1:0",
		APIKey:     apiKey,
		Version:    "0.3.0-test",
		DeviceID:   "CONTRACT-DEV-A",
		DeviceName: "ContractHost",
	}, linuxPal, linuxPal, linkMgr, pairingSvc)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = server.Start(ctx) }()

	var addr string
	for i := 0; i < 60; i++ {
		time.Sleep(25 * time.Millisecond)
		addr = server.Addr()
		if addr != "" {
			if c, err := net.DialTimeout("tcp", addr, 100*time.Millisecond); err == nil {
				_ = c.Close()
				break
			}
		}
	}
	if addr == "" {
		t.Fatalf("server failed to bind")
	}

	baseURL := "http://" + addr + "/api/v1"
	client := &http.Client{Timeout: 2 * time.Second}

	doReq := func(method, path string, body any, token string) (int, []byte) {
		var rdr *bytes.Reader
		if body != nil {
			b, _ := json.Marshal(body)
			rdr = bytes.NewReader(b)
		} else {
			rdr = bytes.NewReader(nil)
		}
		req, err := http.NewRequest(method, baseURL+path, rdr)
		if err != nil {
			t.Fatalf("NewRequest %s %s: %v", method, path, err)
		}
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		req.Header.Set("Content-Type", "application/json")
		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("Do %s %s: %v", method, path, err)
		}
		defer resp.Body.Close()
		buf := new(bytes.Buffer)
		_, _ = buf.ReadFrom(resp.Body)
		return resp.StatusCode, buf.Bytes()
	}

	// 1. Every documented path & method must reject missing or wrong Bearer key with 401
	for path, methods := range spec.Paths {
		concrete := strings.NewReplacer(
			"{deviceId}", "DEV-1",
			"{folderId}", "fld-1",
			"{sessionId}", "snd-1",
		).Replace(path)
		for _, method := range methods {
			if code, _ := doReq(method, concrete, nil, ""); code != http.StatusUnauthorized {
				t.Errorf("%s %s without auth: got %d want 401", method, concrete, code)
			}
			if code, _ := doReq(method, concrete, nil, "invalid-key"); code != http.StatusUnauthorized {
				t.Errorf("%s %s with wrong auth: got %d want 401", method, concrete, code)
			}
		}
	}

	// 2. Validate concrete responses against schemas in docs/openapi.yaml
	code, raw := doReq("GET", "/status", nil, apiKey)
	if code != 200 {
		t.Fatalf("GET /status: %d %s", code, raw)
	}
	var statusObj map[string]any
	_ = json.Unmarshal(raw, &statusObj)
	assertSchema(t, spec, "DaemonStatus", statusObj)

	code, raw = doReq("GET", "/health", nil, apiKey)
	if code != 200 {
		t.Fatalf("GET /health: %d %s", code, raw)
	}
	var healthObj map[string]any
	_ = json.Unmarshal(raw, &healthObj)
	assertSchema(t, spec, "SystemHealth", healthObj)

	code, raw = doReq("GET", "/pairing/code", nil, apiKey)
	if code != 200 {
		t.Fatalf("GET /pairing/code: %d %s", code, raw)
	}
	var pairObj map[string]any
	_ = json.Unmarshal(raw, &pairObj)
	assertSchema(t, spec, "PairingPayload", pairObj)

	expectedCode := pairing.DeriveShortCode("CONTRACT-DEV-A", "PEER-B")
	code, raw = doReq("POST", "/pairing/confirm", map[string]any{
		"targetDeviceId": "PEER-B",
		"confirmedCode":  expectedCode,
	}, apiKey)
	if code != 200 {
		t.Fatalf("POST /pairing/confirm: %d %s", code, raw)
	}
	var pairRes map[string]any
	_ = json.Unmarshal(raw, &pairRes)
	assertSchema(t, spec, "PairingResult", pairRes)

	code, raw = doReq("POST", "/devices", map[string]any{
		"deviceId": "PEER-B",
		"name":     "PeerB",
	}, apiKey)
	if code != 201 {
		t.Fatalf("POST /devices: %d %s", code, raw)
	}
	var devObj map[string]any
	_ = json.Unmarshal(raw, &devObj)
	assertSchema(t, spec, "Device", devObj)

	code, raw = doReq("POST", "/folders", map[string]any{
		"id":   "fld-contract",
		"path": t.TempDir(),
		"type": "sendreceive",
	}, apiKey)
	if code != 201 {
		t.Fatalf("POST /folders: %d %s", code, raw)
	}
	var fldObj map[string]any
	_ = json.Unmarshal(raw, &fldObj)
	assertSchema(t, spec, "Folder", fldObj)

	code, raw = doReq("POST", "/send", map[string]any{
		"targetDeviceId": "PEER-B",
		"filePaths":      []string{"/tmp/example.bin"},
	}, apiKey)
	if code != 202 {
		t.Fatalf("POST /send: %d %s", code, raw)
	}
	var sendObj map[string]any
	_ = json.Unmarshal(raw, &sendObj)
	assertSchema(t, spec, "SendSession", sendObj)
}
