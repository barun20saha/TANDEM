package compat

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"unicode/utf8"
)

// Windows reserved names: CON, PRN, AUX, NUL, COM1-9, LPT1-9 (case-insensitive, with or without extension).
var windowsReservedRegex = regexp.MustCompile(`^(?i:(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]))(\..*)?$`)

// Invalid characters on Windows: < > : " / \ | ? *
const windowsInvalidChars = `<>:"/\|?*`

// OS junk filenames ignored by default.
var defaultIgnorePatterns = []string{
	".DS_Store",
	"Thumbs.db",
	"desktop.ini",
}

// ConflictType categorizes filename or path synchronization conflicts.
type ConflictType string

const (
	ConflictNone          ConflictType = ""
	ConflictCaseCollision ConflictType = "case_collision"
	ConflictReservedName  ConflictType = "reserved_name"
	ConflictInvalidChars  ConflictType = "invalid_chars"
	ConflictTrailingDot   ConflictType = "trailing_dot_space"
)

// CheckNameCompatibility checks if a filename is valid on target OS (Windows, macOS, Linux).
func CheckNameCompatibility(filename string, targetOS string) (ConflictType, string) {
	base := filepath.Base(filename)

	if targetOS == "windows" {
		// 1. Reserved device names
		if windowsReservedRegex.MatchString(base) {
			return ConflictReservedName, fmt.Sprintf("Filename %q is a Windows reserved device name", base)
		}

		// 2. Trailing dots or spaces
		if strings.HasSuffix(base, ".") || strings.HasSuffix(base, " ") {
			return ConflictTrailingDot, fmt.Sprintf("Filename %q ends with a dot or space (invalid on Windows)", base)
		}

		// 3. Invalid characters
		for _, r := range base {
			if strings.ContainsRune(windowsInvalidChars, r) || r < 32 {
				return ConflictInvalidChars, fmt.Sprintf("Filename %q contains invalid character %q for Windows", base, r)
			}
		}
	}

	return ConflictNone, ""
}

// ShouldIgnoreFile returns true if the file or any of its path components is OS junk that should be ignored by default.
func ShouldIgnoreFile(filePath string) bool {
	cleaned := filepath.ToSlash(filePath)
	parts := strings.Split(cleaned, "/")
	for _, part := range parts {
		// Direct match against known OS junk filenames
		for _, ign := range defaultIgnorePatterns {
			if strings.EqualFold(part, ign) {
				return true
			}
		}

		// Prefix match: .Trash*, ~$*
		if strings.HasPrefix(part, ".Trash") || strings.HasPrefix(part, "~$") {
			return true
		}
	}

	return false
}

// DetectCaseCollisions detects if two filenames would collide on a case-insensitive filesystem (Windows / macOS).
func DetectCaseCollisions(names []string) map[string][]string {
	seen := make(map[string][]string)
	for _, n := range names {
		normalized := strings.ToLower(n)
		seen[normalized] = append(seen[normalized], n)
	}

	collisions := make(map[string][]string)
	for k, list := range seen {
		if len(list) > 1 {
			collisions[k] = list
		}
	}
	return collisions
}

// AtomicWriteTemp writes data to a temporary file in the destination folder, verifies its SHA-256 hash,
// and renames it atomically to targetPath upon successful verification.
func AtomicWriteTemp(targetPath string, src io.Reader, expectedHash string) (int64, error) {
	dir := filepath.Dir(targetPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return 0, fmt.Errorf("failed to create directory: %w", err)
	}

	tmpFile, err := os.CreateTemp(dir, ".tandem-tmp-*")
	if err != nil {
		return 0, fmt.Errorf("failed to create temp file: %w", err)
	}
	tmpName := tmpFile.Name()
	defer func() {
		// Cleanup if not successfully renamed
		if _, err := os.Stat(tmpName); err == nil {
			_ = os.Remove(tmpName)
		}
	}()

	hasher := sha256.New()
	writer := io.MultiWriter(tmpFile, hasher)

	written, err := io.Copy(writer, src)
	if err != nil {
		_ = tmpFile.Close()
		return written, fmt.Errorf("failed writing temp file: %w", err)
	}

	if err := tmpFile.Sync(); err != nil {
		_ = tmpFile.Close()
		return written, fmt.Errorf("failed syncing temp file: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return written, fmt.Errorf("failed closing temp file: %w", err)
	}

	// Verify hash if specified
	if expectedHash != "" {
		actualHash := fmt.Sprintf("%x", hasher.Sum(nil))
		if !strings.EqualFold(actualHash, expectedHash) {
			return written, fmt.Errorf("hash verification failed: expected %s, got %s", expectedHash, actualHash)
		}
	}

	// Atomic rename
	if err := os.Rename(tmpName, targetPath); err != nil {
		return written, fmt.Errorf("atomic rename failed: %w", err)
	}

	return written, nil
}

// SafePath checks that the target relative path does not escape root (no symlink traversal outside root).
func SafePath(root, relPath string) (string, error) {
	if strings.HasPrefix(relPath, "/") || strings.HasPrefix(relPath, "\\") {
		return "", errors.New("absolute path traversal outside sync root detected")
	}

	cleaned := filepath.Clean(relPath)
	if strings.HasPrefix(cleaned, "..") || filepath.IsAbs(cleaned) {
		return "", errors.New("path traversal outside sync root detected")
	}

	full := filepath.Join(root, cleaned)
	// Check if symlink
	fi, err := os.Lstat(full)
	if err == nil && fi.Mode()&os.ModeSymlink != 0 {
		target, err := filepath.EvalSymlinks(full)
		if err != nil {
			return "", err
		}
		relToRoot, err := filepath.Rel(root, target)
		if err != nil || strings.HasPrefix(relToRoot, "..") {
			return "", errors.New("symlink target escapes sync root")
		}
	}

	return full, nil
}

// NormalizeForComparison returns a lowercase, clean representation for cross-OS equivalence check.
func NormalizeForComparison(s string) string {
	if !utf8.ValidString(s) {
		return s
	}
	return strings.ToLower(s)
}
