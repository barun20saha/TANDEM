package pairing

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"time"
)

// Session represents an in-progress pairing attempt.
type Session struct {
	LocalDeviceID   string
	LocalDeviceName string
	RemoteDeviceID  string
	RemoteName      string
	ShortCode       string
	Nonce           string
	CreatedAt       time.Time
	Confirmed       bool
}

// Service manages QR generation, code derivation, and pairing confirmation (Section 6).
type Service struct {
	mu              sync.RWMutex
	localDeviceID   string
	localDeviceName string
	sessions        map[string]*Session
}

func NewService(localDeviceID, localDeviceName string) *Service {
	return &Service{
		localDeviceID:   localDeviceID,
		localDeviceName: localDeviceName,
		sessions:        make(map[string]*Session),
	}
}

// DeriveShortCode generates a consistent, human-readable 6-digit confirmation code from two Device IDs.
func DeriveShortCode(idA, idB string) string {
	// Sort IDs to ensure identical derivation on both sides
	first, second := idA, idB
	if strings.Compare(first, second) > 0 {
		first, second = second, first
	}

	hash := sha256.Sum256([]byte(first + ":" + second))
	num := uint32(hash[0])<<24 | uint32(hash[1])<<16 | uint32(hash[2])<<8 | uint32(hash[3])
	code := num % 1000000
	return fmt.Sprintf("%03d-%03d", code/1000, code%1000)
}

// GenerateQRPayload produces a standardized pairing URI (Section 6.2).
// Format: tandem://pair?id=<deviceId>&name=<name>&hint=<addr>&n=<nonce>
func (s *Service) GenerateQRPayload(addrHint string) (string, string, error) {
	nonceBytes := make([]byte, 8)
	if _, err := rand.Read(nonceBytes); err != nil {
		return "", "", err
	}
	nonce := hex.EncodeToString(nonceBytes)

	v := url.Values{}
	v.Set("id", s.localDeviceID)
	v.Set("name", s.localDeviceName)
	if addrHint != "" {
		v.Set("hint", addrHint)
	}
	v.Set("n", nonce)

	qrPayload := "tandem://pair?" + v.Encode()
	shortCode := DeriveShortCode(s.localDeviceID, nonce)

	s.mu.Lock()
	s.sessions[nonce] = &Session{
		LocalDeviceID:   s.localDeviceID,
		LocalDeviceName: s.localDeviceName,
		ShortCode:       shortCode,
		Nonce:           nonce,
		CreatedAt:       time.Now(),
	}
	s.mu.Unlock()

	return qrPayload, shortCode, nil
}

// ParseQRPayload extracts pairing parameters from a scanned QR payload.
func ParseQRPayload(rawURI string) (remoteID, name, hint, nonce string, err error) {
	if !strings.HasPrefix(rawURI, "tandem://pair?") {
		return "", "", "", "", fmt.Errorf("invalid QR scheme; expected tandem://pair")
	}

	u, err := url.Parse(rawURI)
	if err != nil {
		return "", "", "", "", fmt.Errorf("malformed pairing URI: %w", err)
	}

	q := u.Query()
	remoteID = q.Get("id")
	name = q.Get("name")
	hint = q.Get("hint")
	nonce = q.Get("n")

	if remoteID == "" {
		return "", "", "", "", fmt.Errorf("pairing URI missing device ID")
	}

	return remoteID, name, hint, nonce, nil
}

// ConfirmPairing verifies that the user-confirmed code matches the expected short code.
func (s *Service) ConfirmPairing(targetDeviceID, confirmedCode string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	expectedCode := DeriveShortCode(s.localDeviceID, targetDeviceID)
	cleanConfirmed := strings.ReplaceAll(confirmedCode, " ", "")
	cleanExpected := strings.ReplaceAll(expectedCode, " ", "")

	return strings.EqualFold(cleanConfirmed, cleanExpected)
}
