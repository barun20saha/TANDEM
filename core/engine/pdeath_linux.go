//go:build linux

package engine

import (
	"os/exec"
	"syscall"
)

func setChildLifecycle(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Pdeathsig: syscall.SIGTERM,
	}
}
