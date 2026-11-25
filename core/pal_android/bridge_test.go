package pal_android_test

import (
	"testing"

	"tandem/core/pal_android"
)

func TestAndroidBridgeRejectsMissingEngineHonestError(t *testing.T) {
	// Never return fake success when no engine binary exists
	rc := pal_android.StartEngine(t.TempDir(), "/nonexistent/libsyncthing.so")
	if rc == 0 {
		t.Fatalf("expected non-zero failure when engine binary is missing")
	}
	if pal_android.IsEngineActive() != 0 {
		t.Fatalf("expected IsEngineActive() == 0 when engine failed to start")
	}
	if pal_android.LastError() == "" {
		t.Fatalf("expected descriptive LastError() message")
	}
	_ = pal_android.StopEngine()
}
