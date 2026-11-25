# Tandem

[![CI](https://github.com/barun20saha/TANDEM/actions/workflows/ci.yml/badge.svg)](https://github.com/barun20saha/TANDEM/actions/workflows/ci.yml)
[![Release](https://github.com/barun20saha/TANDEM/actions/workflows/release.yml/badge.svg)](https://github.com/barun20saha/TANDEM/actions/workflows/release.yml)
[![Security](https://github.com/barun20saha/TANDEM/actions/workflows/security.yml/badge.svg)](https://github.com/barun20saha/TANDEM/actions/workflows/security.yml)

**Download Tandem:** **[Official Download Page](https://barun20saha.github.io/TANDEM/)** (auto-detects Windows, macOS, Linux, or Android) · [All GitHub Releases](https://github.com/barun20saha/TANDEM/releases)

> One app that sends files, photos, and folders between nearby devices with **no internet**, and keeps a folder identical across all your devices, anywhere in the world, over a **direct encrypted peer-to-peer link**.

---

## 1. Overview

Tandem provides two distinct, clean user-facing modes:

| Mode | User Mental Model | Behavior |
|------|-------------------|-----------|
| **Send** | *"Get this to that device now."* | **One-off.** Pick files or photos, pick a device, done. Ephemeral transmission that terminates cleanly. Nothing keeps syncing afterwards. |
| **Sync** | *"This folder lives on all my devices."* | **Continuous.** Bidirectional mirror. A change on any device immediately propagates to the others. |

**Platforms:** Windows 10/11, macOS, Linux, and Android.

---

## 2. Architecture & Wire Stack

```
┌────────────────────────── UI (Flutter Codebase) ──────────────────────────┐
│ Send screen · Folders · Devices · Link status · Settings                  │
│ Talks only to local tandemd via loopback API. Never touches network raw.  │
└───────────────────────────────▲───────────────────────────────────────────┘
                                │ 127.0.0.1:8385 (Bearer API Key, local only)
┌───────────────────────────────┴───────────────────────────────────────────┐
│ tandemd (Go Daemon)                                                       │
│  ├─ Sync Engine: Headless Syncthing core (REST & SSE events)              │
│  ├─ Link Manager: Watches & migrates links (direct-local, relayed, etc.)  │
│  ├─ Pairing Service: QR / 6-digit tabular match code exchange             │
│  ├─ Send Manager: Ephemeral single-recipient BEP folders                  │
│  ├─ Trash & Versioning: .tandem-trash store with 30-day retention         │
│  ├─ Multipath Scheduler: Plexo block-level weighted scheduling & failover │
│  └─ Platform Abstraction Layer (PAL): Isolates OS differences behind APIs │
└───────────────────────────────▲───────────────────────────────────────────┘
                                │ OS APIs: sockets, firewall, hotspot,
                                │ storage, power/lifecycle, notifications
        Linux Adapter · Windows Adapter · macOS Adapter · Android Adapter
```

### Layered Wire Stack
```
L5  App:        Folders, Send sessions, pairing
L4  Protocol:   Block Exchange Protocol (BEP v1), blocks of file data + metadata
L3  Security:   TLS 1.3, mutual authentication by device certificate (Device ID)
L2  Transport:  QUIC over UDP, or TCP on port 22000 (or relay over TCP 22067)
L1  Network:    IPv4 / IPv6
L0  Link:       Wi-Fi LAN · Phone/Laptop hotspot · Ethernet · USB tether
```

---

## 3. Repository Layout

```
tandem/
  ├── core/                 # Go daemon, PAL adapters, engine, and APIs
  │   ├── api/              # Localhost REST & SSE Server (127.0.0.1:8385)
  │   ├── cmd/tandemd/      # Daemon executable entrypoint
  │   ├── discovery/        # Per-interface UDP 21027 broadcast, self-test & P2P
  │   ├── engine/           # Headless engine supervisor & config generator
  │   │   └── compat/       # Cross-OS filename safety, atomic writes & symlink guards
  │   ├── folders/          # Folder manager (SendReceive, SendOnly, ReceiveOnly)
  │   ├── linkmanager/      # Connection classification & relayed-to-direct migrator
  │   ├── multipath/        # Multipath block scheduler (Plexo model)
  │   ├── pairing/          # QR payload & 6-digit code derivation
  │   ├── pal/              # Platform Abstraction Layer interfaces & contract tests
  │   ├── pal_linux/        # Linux PAL adapter (systemd, ufw, firewalld, inotify)
  │   ├── pal_windows/      # Windows PAL adapter (firewall rules, power assertions)
  │   ├── pal_darwin/       # macOS PAL adapter (SMAppService, Local Network privacy)
  │   ├── pal_android/      # Android PAL adapter (in-process JNI library bridge)
  │   ├── send/             # Ephemeral Send session manager
  │   └── trash/            # .tandem-trash store with 30-day retention & recovery
  ├── app/                  # UI application (Flutter)
  │   ├── android/          # Android Native wrapper & Foreground Service
  │   └── lib/              # Flutter Dart UI codebase
  │       ├── components/   # Design system components (LinkLine, DeviceRow, etc.)
  │       ├── l10n/         # Localized copy deck (app_en.json)
  │       ├── screens/      # Gallery, LinkStatusScreen, NoInternetHelperScreen
  │       └── theme/        # Auto-generated Dart tokens (tokens.dart)
  ├── design/               # Design tokens, components documentation & audits
  │   ├── tokens.json       # Single source of truth for design tokens
  │   ├── AUDIT.md          # Automated token coverage & completeness audit (100%)
  │   ├── components.md     # Component catalog, states, and accessibility rules
  │   ├── generate_tokens.py# Compiler emitting Flutter theme constants
  │   └── handoff/          # Specifications for Screens S1 through S11
  ├── infra/                # Self-hosted relay & discovery (Docker Compose)
  ├── scripts/              # Standalone packaging (.deb, .app/dmg, .ps1)
  ├── tests/                # Chaos testing suite (network drop, disk full, sleep)
  ├── docs/                 # Architectural logs & verification records
  │   ├── DECISIONS.md      # Record of decisions (D1–D5) and upstream verifications (V1–V7)
  │   ├── PLATFORM_STATUS.md# OS capability matrix & release verification
  │   ├── MEASUREMENTS.md   # Benchmarks across all Section 11.1 scenarios
  │   └── RESEARCH.md       # Usability study protocol and findings
  └── THIRD_PARTY_NOTICES.md# Open-source licences (MPL-2.0, MIT, OFL-1.1)
```

---

## 4. Getting Started

### Prerequisites
- **Go:** 1.24+
- **Python:** 3.8+ (for token generation & audits)
- **Docker:** Optional (for self-hosted `infra/` stack)

### 1. Build the Desktop Daemon
```bash
cd core
go build -o ../bin/tandemd ./cmd/tandemd
./../bin/tandemd -version
```

### 2. Run the Test Suites
```bash
# 1. Run all Core unit and integration tests
cd core
go test ./...

# 2. Run Chaos & Hardening tests
cd ../tests
go test ./...

# 3. Verify Design Token Coverage (target: 0 violations)
python3 ../design/audit.py
```

### 3. Run Self-Hosted Private Relay & Discovery Stack
```bash
cd infra
docker compose up -d
curl http://localhost:22070/status
```

---

## 5. Design System & Signature Element

- **Signature Element — `LinkLine`:** Visual representation of peer connection topology:
  - `direct-local`: **Solid line** (Same LAN, hotspot, or cable).
  - `direct-internet`: **Dashed line** (Direct connection over internet via NAT hole punching).
  - `relayed`: **Dotted line** (Encrypted relay server, labeled *"Through a relay (slower)"*).
  - `connecting`: **Muted dashed line**.
  - `offline`: **Not reachable**.
  - *Rule:* Always paired with a visible text label and semantic screen reader description; never relies on color alone.
- **Tokens & Coverage:** Single source of truth in `design/tokens.json`. **0 hard-coded hex colors or spacing values outside tokens.**

---

## 6. Safety & Resilience

- **Never Silently Delete User Data (Rule 6):** Every deleted or overwritten file routes into `.tandem-trash` with 30-day retention and one-click recovery.
- **Atomic Writes:** Incoming files are written to `.tandem-tmp-*`, verified against their SHA-256 hash, and atomically renamed. In-flight write failures (such as disk full) cleanly abort with zero corruption of existing user files.
- **Failover:** If an active network interface drops mid-transfer, the multipath scheduler re-allocates in-flight blocks to surviving links without restarting the transfer.
- **Sleep & Wake Recovery:** Automatically triggers local re-announcements within 2 seconds upon system resume.

---

## 7. Licences

Tandem is documented in [THIRD_PARTY_NOTICES.md](file:///home/barun/Desktop/TANDEM/THIRD_PARTY_NOTICES.md).
- Syncthing Core (MPL-2.0)
- Plexo multipath concept (MIT)
- Familjen Grotesk & Atkinson Hyperlegible Next fonts (OFL-1.1)
