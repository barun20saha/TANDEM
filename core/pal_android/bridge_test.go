package pal_android_test

import (
	"testing"

	"tandem/core/pal_android"
)

func TestAndroidBridgeLifecycle(t *testing.T) {
	ret := pal_android.StartEngine("/tmp/test-android-config")
	if ret != 0 {
		t.Errorf("StartEngine returned %d, expected 0", ret)
	}

	if pal_android.IsEngineActive() != 1 {
		t.Errorf("expected engine to be active")
	}

	ret = pal_android.StopEngine()
	if ret != 0 {
		t.Errorf("StopEngine returned %d, expected 0", ret)
	}

	if pal_android.IsEngineActive() != 0 {
		t.Errorf("expected engine to be inactive")
	}
}
