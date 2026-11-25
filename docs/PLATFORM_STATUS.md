# Platform Support and Testing Status

This document records only verified operational status, test methods, and capabilities observed from real runs (see [docs/TRIAGE.md](TRIAGE.md) and [docs/evidence/](evidence/)).

---

## 1. Operating System Status Matrix

| Feature | Linux (`x86_64`) | Windows (10/11) | macOS (13+) | Android (8+) |
|---|---|---|---|---|
| **Verification Status** | **Tested locally (`Linux Mint 22.3`) & in CI (`ubuntu-latest`)** | **Cross-compile only (`GOOS=windows` build); runtime untested** | **Cross-compile only (`GOOS=darwin` build); runtime untested** | **Untested on hardware; APK blocked on user device (see WS4)** |
| **tandemd Background Daemon** | Supervised `syncthing v2.1.7` + `127.0.0.1:8385` REST/SSE API (`systemd --user` unit generation unit-tested) | Untested at runtime (`pal_windows` contains stubs) | Untested at runtime (`pal_darwin` contains stubs) | Stub `pal_android/bridge.go` only (`libtandemd.so` does not embed sync engine yet) |
| **Identity (TLS Cert & Device ID)** | **Confirmed** (`cert.pem`, `key.pem` `0600`, persistent across restarts) | Untested | Untested | Untested |
| **Local Discovery (`UDP 21027`)** | **Confirmed** (`SO_REUSEPORT` per-interface broadcast & discovery of unpaired peers) | Untested | Untested | Untested |
| **Direct BEP Sync (`TCP/QUIC 22000`)** | **Confirmed** (1 GB + 1,000 files `MATCH`, edit/delete, conflict, `kill -9` resume) | Untested | Untested | Untested |
| **No-Internet Sync** | **Confirmed** (isolated `-global-discovery=false -relays=false -nat=false`; `ip netns` when root) | Untested | Untested | Untested |
| **Trash & Recovery (`.tandem-trash`)** | **Confirmed** (30-day `trashcan` versioning + API restore) | Untested | Untested | Untested |
| **Ephemeral Send (D2)** | **Confirmed** (`sendonly` -> `receiveonly` over BEP + auto-cleanup) | Untested | Untested | Untested |
| **Hotspot Create / Join** | `nmcli` / `iw list` unit-checked; hardware AP creation **untested** | Unsupported without internet (D/V3) | Unsupported (no public API, V4) | Untested |
| **Power / Sleep-Wake** | `systemd-inhibit` executed; `OnResume`/`OnSuspend` hooks are **unwired** | Stub / Untested | Stub / Untested | Kotlin service code written; **untested** on device |
| **Firewall Detection** | `ufw`/`firewalld` command checks unit-tested; live rule blocking **untested** | Stub (`FirewallOpen` hardcoded) | Stub (`FirewallOpen` hardcoded) | N/A |

---

## 2. Linux Test Verification Log (WS1)

- **Test Suite:** `tests/e2e/e2e_test.go` running real `tandemd` + `syncthing v2.1.7` processes across separate config directories and ports ([evidence log](evidence/e2e-2026-11-25.log)).
- **Results (`go test -v -count=1 ./e2e`):**
  1. `TestE2E_BootAndAuth`: PASS — creates `api.key`, `cert.pem`, `key.pem` (`0600`), listens on API/sync/discovery ports, rejects missing/wrong key with `401`, preserves Device ID across restart.
  2. `TestE2E_Discover`: PASS — instance A discovers instance B over UDP without an address hint.
  3. `TestE2E_PairAndSync1GBAnd1000Files`: PASS (`MATCH`) — pairs A & B, syncs 1 GB random file + 1,000 small files with matching SHA-256 hashes.
  4. `TestE2E_EditDeleteAndTrashRestore`: PASS — propagates edit & delete, preserves deleted file in B's `.tandem-trash`, restores via `POST /api/v1/folders/{id}/trash/restore`.
  5. `TestE2E_Conflict`: PASS — concurrent edits while B is stopped preserve both copies (`.sync-conflict-*`).
  6. `TestE2E_FilenamesAndWarnings`: PASS — syncs `Photo.jpg`, `photo.jpg`, `café.txt`, `CON.txt` without data loss and surfaces `case_collision` and `reserved_name` warnings via `/folders/{id}/errors`.
  7. `TestE2E_Kill9Resume`: PASS — `kill -9` on receiver mid-transfer resumes on restart with matching final SHA-256.
  8. `TestE2E_DiskFull`: PASS — receiver enforces free-space limit (`tmpfs` when root, `minDiskFree` floor when unprivileged), keeps existing files intact, and reports `err.disk_full`.
  9. `TestE2E_NoInternet`: PASS — sync succeeds with global discovery, relays, and NAT disabled (`ip netns` isolation when root).
  10. `TestE2E_SendAndLinkStateSSE`: PASS — ephemeral Send transfers payload with matching SHA-256, `/devices` reports real `direct-local` then `offline` after shutdown, and `/events` streams live SSE events.
