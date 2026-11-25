package pairing_test

import (
	"testing"

	"tandem/core/pairing"
)

func TestDeriveShortCodeSymmetric(t *testing.T) {
	idA := "SJBWNHB-EM4S5Z7-MR6BCEU-W4HUOUY-7L3IAZU-S3CRZFM-S7L5ROK-D3H3CQU"
	idB := "CGOEDOR-XTGKBX3-HVHHR5C-AHRRIRP-55QIUND-PVP4TAD-CN76YTM-OTVSDQ3"

	c1 := pairing.DeriveShortCode(idA, idB)
	c2 := pairing.DeriveShortCode(idB, idA)
	if c1 == "" || c1 != c2 {
		t.Fatalf("expected symmetric short code, got %q vs %q", c1, c2)
	}
}

func TestQRPayloadRoundTripAndConfirm(t *testing.T) {
	idA := "DEV-LOCAL-AAA"
	idB := "DEV-REMOTE-BBB"
	svc := pairing.NewService(idA, "Laptop")

	uri, _, err := svc.GenerateQRPayload("tcp://192.168.1.10:22000")
	if err != nil {
		t.Fatalf("GenerateQRPayload: %v", err)
	}
	remoteID, name, hint, nonce, err := pairing.ParseQRPayload(uri)
	if err != nil {
		t.Fatalf("ParseQRPayload: %v", err)
	}
	if remoteID != idA || name != "Laptop" || hint != "tcp://192.168.1.10:22000" || nonce == "" {
		t.Fatalf("unexpected parsed QR fields: %q %q %q %q", remoteID, name, hint, nonce)
	}

	code := pairing.DeriveShortCode(idA, idB)
	if !svc.ConfirmPairing(idB, code) {
		t.Fatalf("expected ConfirmPairing true for matching code")
	}
	if svc.ConfirmPairing(idB, "000-000") {
		t.Fatalf("expected ConfirmPairing false for mismatched code")
	}
}
