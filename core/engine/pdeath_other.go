//go:build !linux

package engine

import "os/exec"

func setChildLifecycle(cmd *exec.Cmd) {}
