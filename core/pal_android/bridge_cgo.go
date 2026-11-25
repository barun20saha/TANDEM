//go:build cgo

package pal_android

// CGO C-shared entrypoints live in core/cmd/tandemd_android/main.go because
// Go's -buildmode=c-shared requires a main package.
