# 🍯 Cowrie Honeypot with WireGuard Relay + Grafana Geomap

![Status](https://img.shields.io/badge/status-active-brightgreen)
![Platform](https://img.shields.io/badge/platform-Proxmox%20LXC-orange)
![Honeypot](https://img.shields.io/badge/honeypot-Cowrie-blue)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

A home-lab SSH honeypot built on Proxmox, exposed to the real internet through a WireGuard tunnel to a cheap VPS (to work around CGNAT), with attacker sessions logged, geolocated, and visualized live on a Grafana world map.

> 💡 Add a screenshot of your live Geomap dashboard here once it's populated with real traffic — it's the best way to show what this actually does.

## Table of contents

- [Why](#why)
- [Architecture](#architecture)
- [Stack](#stack)
- [Repo layout](#repo-layout)
- [Setup guide](#setup-guide)
  - [1. Network isolation](docs/01-network-isolation.md)
  - [2. Container](docs/02-container-setup.md)
  - [3. Cowrie install](docs/03-cowrie-install.md)
  - [4. Port redirect](docs/04-port-redirect.md)
  - [5. WireGuard tunnel](docs/05-wireguard-tunnel.md)
  - [6. Log pipeline](docs/06-log-pipeline.md)
  - [7. Grafana dashboard](docs/07-grafana-dashboard.md)
- [Gotchas & lessons learned](docs/gotchas.md)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Ethics & legality](#ethics--legality)
- [Contributing](#contributing)
- [License](#license)

## Why

Home ISPs increasingly sit behind CGNAT, so there's no public IP to forward a port to. This project solves that by running the honeypot at home — fully isolated from the rest of the homelab — and relaying inbound traffic to it through a small VPS with a real public IP. No home network exposure, and genuine attacker source IPs are still captured (not hidden behind the tunnel).

## Architecture

```
Internet
   │
   ▼
┌─────────────────────────┐
│   VPS (public IP)       │
│   sshd → :2200          │
│   DNAT :22 → tunnel     │
└───────────┬─────────────┘
            │ WireGuard
┌───────────▼─────────────┐
│   Home / Proxmox         │
│  ┌─────────────────────┐ │
│  │ Honeypot LXC          │ │  isolated bridge, NAT-only egress
│  │  Cowrie :2222         │ │
│  │  Promtail (+ GeoIP)   │ │
│  └─────────────────────┘ │
│  ┌─────────────────────┐ │
│  │ Monitoring LXC        │ │  existing box
│  │  Loki                 │ │
│  │  Grafana (Geomap)     │ │
│  └─────────────────────┘ │
└──────────────────────────┘
```

## Stack

| Component | Role | Repo path |
|---|---|---|
| [Cowrie](https://github.com/cowrie/cowrie) | Medium-interaction SSH/Telnet honeypot | — |
| Proxmox LXC | Isolated container, own bridge/subnet | [`docs/01-network-isolation.md`](docs/01-network-isolation.md) |
| WireGuard | Tunnel between VPS and honeypot, solves CGNAT | [`configs/wireguard/`](configs/wireguard) |
| Any VPS | Public-facing relay endpoint | [`docs/05-wireguard-tunnel.md`](docs/05-wireguard-tunnel.md) |
| Promtail | Log shipping + GeoIP enrichment | [`configs/promtail/`](configs/promtail) |
| Loki | Log storage/indexing | [`docs/06-log-pipeline.md`](docs/06-log-pipeline.md) |
| Grafana | Geomap dashboard | [`docs/07-grafana-dashboard.md`](docs/07-grafana-dashboard.md) |
| MaxMind GeoLite2 | IP → location database | [`docs/06-log-pipeline.md`](docs/06-log-pipeline.md) |

## Repo layout

```
.
├── README.md
├── LICENSE
├── docs/
│   ├── 01-network-isolation.md
│   ├── 02-container-setup.md
│   ├── 03-cowrie-install.md
│   ├── 04-port-redirect.md
│   ├── 05-wireguard-tunnel.md
│   ├── 06-log-pipeline.md
│   ├── 07-grafana-dashboard.md
│   └── gotchas.md
├── configs/
│   ├── wireguard/
│   │   ├── honeypot.wg0.conf.example
│   │   └── vps.wg0.conf.example
│   ├── promtail/
│   │   └── config.yaml.example
│   └── systemd/
│       └── cowrie.service
├── scripts/
│   ├── setup-bridge.sh
│   ├── setup-dnat.sh
│   └── test-tunnel.sh
└── .github/
    └── ISSUE_TEMPLATE/
        └── bug_report.md
```

## Setup guide

Follow the numbered docs in order — each stage assumes the previous one is working before moving on.

1. **[Network isolation](docs/01-network-isolation.md)** — dedicated bridge, no route to the real LAN
2. **[Container setup](docs/02-container-setup.md)** — unprivileged LXC on the isolated bridge
3. **[Cowrie install](docs/03-cowrie-install.md)** — pip install, systemd service
4. **[Port redirect](docs/04-port-redirect.md)** — real port 22 → Cowrie's 2222
5. **[WireGuard tunnel](docs/05-wireguard-tunnel.md)** — the CGNAT workaround, plus the real-IP fix
6. **[Log pipeline](docs/06-log-pipeline.md)** — Promtail → Loki, with GeoIP enrichment
7. **[Grafana dashboard](docs/07-grafana-dashboard.md)** — the Geomap panel, query, and transforms

If something doesn't work as expected, check **[gotchas & lessons learned](docs/gotchas.md)** first — several non-obvious issues came up building this that aren't well documented elsewhere.

## Known limitations

- No lines drawn between attacker location and host on the map — Grafana's Route layer only connects sequential points across rows (built for GPS tracks), not per-row origin/destination pairs. The newer **Network** layer (Grafana 10.1+) is designed for this.
- Egress from the honeypot subnet should be locked to only what's needed (DNS/HTTPS) as defense-in-depth.
- VPS password auth should be disabled once key-based access is confirmed working (left enabled in the initial build).

## Roadmap

- [ ] Attacker-to-host line rendering via Grafana's Network layer
- [ ] Egress lockdown verification/hardening script
- [ ] Optional [T-Pot](https://github.com/telekom-security/tpotce) node for broader multi-protocol coverage
- [ ] Automated MaxMind DB refresh (cron)
- [ ] Terraform/Ansible for repeatable VPS provisioning

## Ethics & legality

This project only observes — it never touches an attacker's system. **Do not** attempt to retaliate against source IPs seen in the logs: unauthorized access to another system is illegal regardless of provocation (e.g. the Computer Fraud and Abuse Act in the US, the Cybercrime Act 2001 in Australia), and the IPs you see are very often themselves compromised third-party machines, not the actual operator.

## Contributing

Issues and PRs welcome — see [`.github/ISSUE_TEMPLATE/bug_report.md`](.github/ISSUE_TEMPLATE/bug_report.md) for the bug report format. This is a personal homelab project, so response times may vary.

## License

MIT — see [LICENSE](LICENSE).
