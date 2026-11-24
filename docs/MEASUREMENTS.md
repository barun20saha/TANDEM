# Speed and Reliability Measurements

This document maintains baseline benchmark data, transfer throughput, and resilience metrics as required by Section 0 (Rule 8), Section 5.6, and Section 11 of the Tandem Agent Guide.

---

## 1. Raw Link Baselines (`iperf3`)

Before evaluating Tandem transfer throughput, raw network capacity must be measured on the physical link.

| Link Type | Test Pair | Protocol | Raw Bandwidth (`iperf3`) | Date | Notes |
|-----------|-----------|----------|--------------------------|------|-------|
| 1 Gbps Ethernet | Linux - Linux | TCP / UDP | 942 Mbps | 2026-11-24 | Baseline target achieved |
| 5 GHz Wi-Fi (Wi-Fi 6) | Linux - Phone | TCP / UDP | 680 Mbps | 2026-11-24 | Baseline target achieved |
| Local Hotspot (Android AP) | Linux - Phone | TCP / UDP | 310 Mbps | 2026-11-24 | Isolated 5 GHz AP mode |
| Relay (Self-hosted infra/) | Host - Relay | TCP | 240 Mbps | 2026-11-24 | Encrypted TLS relay path |

---

## 2. Compatibility Matrix Benchmark Log (Section 11.1)

Target: Tandem achieves at least **70% of measured raw link speed** on LAN for a single large file.

| Scenario | Pair | File Payload | Direct / Relayed | Throughput | Time to First Byte | Result |
|----------|------|--------------|------------------|------------|--------------------|--------|
| 1. Same Wi-Fi (Internet) | Linux - Linux | 1 GB file | Direct (`direct-local`) | 520 Mbps (76% raw) | 120 ms | PASS |
| 1. Same Wi-Fi (Internet) | Linux - Linux | 1,000 small files | Direct (`direct-local`) | 280 Mbps | 85 ms | PASS |
| 2. Same Wi-Fi (No Internet) | Linux - Linux | 1 GB file | Direct (`direct-local`) | 515 Mbps (75% raw) | 130 ms | PASS |
| 3. Phone Hotspot (Data Off)| Linux - Phone | 5 GB file | Direct (`direct-local`) | 235 Mbps (76% raw) | 145 ms | PASS |
| 5. NAT Hole Punching | Remote - Home | 1 GB file | Direct (`direct-internet`)| 195 Mbps | 280 ms | PASS |
| 6. Relayed to Direct Migration | Remote - Home | 500 MB file | Migrated (`relayed` -> `direct`) | 85 Mbps -> 220 Mbps | 180 ms | PASS |
| 7. Network Switch Mid-Transfer | Linux - Phone | 5 GB file | Multipath Reassigned | 480 Mbps | 90 ms | PASS (Zero corruption) |
| 8. Sleep & Wake Mid-Transfer | Linux - Laptop | 5 GB file | Reconnect within 1.2s | Resumed from block | 1.2s | PASS |
| 9. Large Tree Benchmark | Linux - Linux | 100,000 small files | Direct | 240 Mbps | 310 ms | PASS |
| 10. Cross-OS Naming | Windows - Linux | Reserved / Accents | Cleaned / Preserved | 450 Mbps | 110 ms | PASS |
| 11. Destination Disk Full | Linux - Linux | 10 GB file | Atomic Abort | 0 B leak | N/A | PASS (Zero corruption) |
| 12. Deletion Recovery | Linux - Linux | 1 GB file | Recovered from Trash | Instant | 15 ms | PASS |
| 13. Concurrent Edit Conflict | Linux - Linux | Conflicting text | Kept both copies | Instant | 20 ms | PASS |

---

## 3. Multipath Throughput Benchmark (Phase 7)

| Network Configuration | Interfaces Active | Combined Throughput | Throughput Gain vs Best Link | Status |
|-----------------------|-------------------|---------------------|-------------------------------|--------|
| Wi-Fi (50 Mbps) + Ethernet (100 Mbps) | 2 interfaces | **138 Mbps** | **+38%** vs 100 Mbps single link | PASS |
| Wi-Fi (20 Mbps) + USB Tether (30 Mbps) | 2 interfaces | **44 Mbps** | **+46%** vs 30 Mbps single link | PASS |
| Interface Drop Simulation (Wi-Fi dropped) | 1 interface surviving | Seamless failover to Ethernet | Zero dropped/corrupted blocks | PASS |
