# Speed and Reliability Measurements

This document maintains baseline benchmark data, transfer throughput, and resilience metrics as required by Section 0 (Rule 8), Section 5.6, and Section 11 of the Tandem Agent Guide.

---

## 1. Raw Link Baselines (`iperf3`)

Before evaluating Tandem transfer throughput, raw network capacity must be measured on the physical link.

| Link Type | Test Pair | Protocol | Raw Bandwidth (`iperf3`) | Date | Notes |
|-----------|-----------|----------|--------------------------|------|-------|
| 1 Gbps Ethernet | TBD | TCP / UDP | TBD | - | Baseline target |
| 5 GHz Wi-Fi (Wi-Fi 6) | TBD | TCP / UDP | TBD | - | Baseline target |
| Local Hotspot (Android AP) | TBD | TCP / UDP | TBD | - | Baseline target |
| Relay (Community / Self-hosted) | TBD | TCP | TBD | - | Baseline target |

---

## 2. Compatibility Matrix Benchmark Log (Section 11.1)

Target: Tandem achieves at least **70% of measured raw link speed** on LAN for a single large file.

| Scenario | Pair | File Payload | Direct / Relayed | Throughput | Time to First Byte | Result |
|----------|------|--------------|------------------|------------|--------------------|--------|
| 1. Same Wi-Fi (Internet) | TBD | 1 GB file | Direct | TBD | TBD | Pending |
| 1. Same Wi-Fi (Internet) | TBD | 1,000 small files | Direct | TBD | TBD | Pending |
| 2. Same Wi-Fi (No Internet) | TBD | 1 GB file | Direct | TBD | TBD | Pending |
| 3. Phone Hotspot (Data Off)| TBD | 5 GB file | Direct | TBD | TBD | Pending |
| 7. Network Switch Mid-Transfer | TBD | 5 GB file | Direct | TBD | TBD | Pending |
| 8. Sleep & Wake Mid-Transfer | TBD | 5 GB file | Direct | TBD | TBD | Pending |
