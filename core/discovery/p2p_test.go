package discovery_test

import (
	"testing"

	"tandem/core/discovery"
)

func TestRouterlessP2PCapabilities(t *testing.T) {
	cases := []struct {
		osA       string
		osB       string
		supported bool
		isExp     bool
	}{
		{"android", "android", true, false},
		{"android", "linux", true, true},
		{"android", "macos", false, false},
		{"android", "darwin", false, false},
		{"windows", "android", false, false},
		{"linux", "macos", false, false},
	}

	for _, tc := range cases {
		cap := discovery.CheckRouterlessSupport(tc.osA, tc.osB)
		if cap.Supported != tc.supported {
			t.Errorf("CheckRouterlessSupport(%s, %s): expected supported=%v, got %v (%s)", tc.osA, tc.osB, tc.supported, cap.Supported, cap.Notes)
		}
		if cap.Experimental != tc.isExp {
			t.Errorf("CheckRouterlessSupport(%s, %s): expected experimental=%v, got %v", tc.osA, tc.osB, tc.isExp, cap.Experimental)
		}
		if !cap.Supported && cap.FallbackFlow == "" {
			t.Errorf("unsupported OS pair must specify a fallback flow")
		}
	}
}
