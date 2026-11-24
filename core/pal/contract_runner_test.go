package pal_test

import (
	"testing"

	"tandem/core/pal_android"
	"tandem/core/pal_darwin"
	"tandem/core/pal_linux"
	"tandem/core/pal_windows"
)

func TestAllAdaptersAgainstContract(t *testing.T) {
	t.Run("LinuxAdapterContract", func(t *testing.T) {
		a := pal_linux.NewLinuxAdapter()
		RunPALContractTests(t, a, a, a, a, a, a, a)
	})

	t.Run("WindowsAdapterContract", func(t *testing.T) {
		a := pal_windows.NewWindowsAdapter()
		RunPALContractTests(t, a, a, a, a, a, a, a)
	})

	t.Run("DarwinAdapterContract", func(t *testing.T) {
		a := pal_darwin.NewDarwinAdapter()
		RunPALContractTests(t, a, a, a, a, a, a, a)
	})

	t.Run("AndroidAdapterContract", func(t *testing.T) {
		a := pal_android.NewAndroidAdapter()
		RunPALContractTests(t, a, a, a, a, a, a, a)
	})
}
