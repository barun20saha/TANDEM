# Self-Hosted Tandem Relay and Discovery Infrastructure

This directory provides one-command deployment of self-hosted relay and discovery servers for Tandem, enabling high-speed, private transfers when devices are behind strict NAT or firewall boundaries (Section 2.1 & Phase 6).

---

## 1. Quick Start

Run the entire private infrastructure stack with Docker Compose:

```bash
cd infra
docker compose up -d
```

Verify service status:

```bash
docker compose ps
curl http://localhost:22070/status
```

---

## 2. Ports and Network Protocol

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| **Relay Server (`strelaysrv`)** | `22067` | TCP | Encrypted block transfer relay |
| **Relay Status** | `22070` | HTTP | Health check and bandwidth metrics |
| **Discovery Server (`discosrv`)**| `8443` | HTTPS | Global device ID address discovery |

---

## 3. Configuring Tandem to Use Your Server

1. Open Tandem **Settings** > **Advanced Network**.
2. Under **Relay Server**, select **Custom** and enter:
   ```
   relay://your-server-ip:22067
   ```
3. Under **Discovery Server**, enter:
   ```
   https://your-server-ip:8443/
   ```
4. All traffic passing through the relay server remains **end-to-end encrypted** using the devices' long-lived TLS certificates. The relay operator cannot inspect, read, or tamper with file contents.
