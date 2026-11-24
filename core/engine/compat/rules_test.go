package compat_test

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"tandem/core/engine/compat"
)

func TestWindowsReservedNames(t *testing.T) {
	cases := []struct {
		name     string
		conflict compat.ConflictType
	}{
		{"CON.txt", compat.ConflictReservedName},
		{"aux.png", compat.ConflictReservedName},
		{"Nul", compat.ConflictReservedName},
		{"COM1", compat.ConflictReservedName},
		{"lpt9.dat", compat.ConflictReservedName},
		{"normal.txt", compat.ConflictNone},
		{"constant.go", compat.ConflictNone},
		{"CON_file.txt", compat.ConflictNone},
	}

	for _, tc := range cases {
		cType, msg := compat.CheckNameCompatibility(tc.name, "windows")
		if cType != tc.conflict {
			t.Errorf("CheckNameCompatibility(%q, windows) = %v (msg: %s); expected %v", tc.name, cType, msg, tc.conflict)
		}
	}
}

func TestWindowsInvalidCharsAndTrailing(t *testing.T) {
	cases := []struct {
		name     string
		conflict compat.ConflictType
	}{
		{"hello:world.txt", compat.ConflictInvalidChars},
		{"file?.pdf", compat.ConflictInvalidChars},
		{"star*.jpg", compat.ConflictInvalidChars},
		{"trailing.", compat.ConflictTrailingDot},
		{"trailing ", compat.ConflictTrailingDot},
		{"clean_file.txt", compat.ConflictNone},
	}

	for _, tc := range cases {
		cType, _ := compat.CheckNameCompatibility(tc.name, "windows")
		if cType != tc.conflict {
			t.Errorf("CheckNameCompatibility(%q, windows) = %v; expected %v", tc.name, cType, tc.conflict)
		}
	}
}

func TestShouldIgnoreOSJunk(t *testing.T) {
	ignored := []string{
		".DS_Store",
		"Thumbs.db",
		"desktop.ini",
		".Trash-1000",
		".Trash/501",
		"~$MyDocument.docx",
	}
	for _, f := range ignored {
		if !compat.ShouldIgnoreFile(f) {
			t.Errorf("expected %q to be ignored", f)
		}
	}

	allowed := []string{
		"notes.md",
		"trash.png",
		"document.docx",
	}
	for _, f := range allowed {
		if compat.ShouldIgnoreFile(f) {
			t.Errorf("expected %q NOT to be ignored", f)
		}
	}
}

func TestDetectCaseCollisions(t *testing.T) {
	files := []string{
		"README.md",
		"readme.md",
		"Photos",
		"photos",
		"unique.txt",
	}

	collisions := compat.DetectCaseCollisions(files)
	if len(collisions) != 2 {
		t.Fatalf("expected 2 collisions, got %d (%v)", len(collisions), collisions)
	}
	if len(collisions["readme.md"]) != 2 {
		t.Errorf("expected 2 items for readme.md collision")
	}
	if len(collisions["photos"]) != 2 {
		t.Errorf("expected 2 items for photos collision")
	}
}

func TestAtomicWriteTempAndHashVerification(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "tandem-compat-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	content := []byte("Tandem P2P secure sync verified payload.")
	hash := fmt.Sprintf("%x", sha256.Sum256(content))
	target := filepath.Join(tmpDir, "subfolder", "verified.txt")

	written, err := compat.AtomicWriteTemp(target, bytes.NewReader(content), hash)
	if err != nil {
		t.Fatalf("AtomicWriteTemp failed: %v", err)
	}
	if written != int64(len(content)) {
		t.Errorf("written bytes mismatch: got %d, expected %d", written, len(content))
	}

	readBack, err := os.ReadFile(target)
	if err != nil {
		t.Fatalf("ReadFile failed: %v", err)
	}
	if !bytes.Equal(readBack, content) {
		t.Errorf("content mismatch")
	}

	// Test hash mismatch
	badTarget := filepath.Join(tmpDir, "bad.txt")
	_, err = compat.AtomicWriteTemp(badTarget, bytes.NewReader(content), "0000000000000000000000000000000000000000000000000000000000000000")
	if err == nil {
		t.Errorf("expected error on hash mismatch, got nil")
	}
	if _, statErr := os.Stat(badTarget); statErr == nil {
		t.Errorf("bad target file should not exist after failed hash check")
	}
}

func TestSafePathEscapePrevention(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "tandem-safepath-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Valid path
	safe, err := compat.SafePath(tmpDir, "folder/file.txt")
	if err != nil {
		t.Fatalf("SafePath failed on valid path: %v", err)
	}
	if !filepath.IsAbs(safe) {
		t.Errorf("SafePath must return absolute path")
	}

	// Escape attempts
	escapes := []string{
		"../outside.txt",
		"folder/../../outside.txt",
		"/etc/passwd",
	}
	for _, esc := range escapes {
		_, err := compat.SafePath(tmpDir, esc)
		if err == nil {
			t.Errorf("SafePath expected error for escape path %q, got nil", esc)
		}
	}
}
