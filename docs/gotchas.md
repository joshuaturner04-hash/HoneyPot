# Gotchas & lessons learned

A running list of non-obvious issues hit while building this, in case they save someone else time.

## Cowrie

- **No `bin/cowrie` script in current releases.** Cowrie moved to a pip-installable package with a `cowrie` console-script entry point. `pip install -e .` (from the repo root, inside the venv) is what creates the command.
- **Config templates moved.** `cowrie.cfg.dist` and `userdb.example` now live under `src/cowrie/data/etc/`, not the top-level `etc/` (which is reserved for your live config and is `.gitignore`'d upstream).
- **Systemd `FileNotFoundError: twistd`.** The `cowrie` script execs `twistd` by name, relying on it being on `PATH`. Running manually after `source cowrie-env/bin/activate` works because the venv's `bin/` is on `PATH` — but systemd doesn't know about that activation. Fix: set `Environment="PATH=.../cowrie-env/bin:/usr/bin:/bin"` explicitly in the unit file.

## Debian socket activation

- **`systemctl disable ssh` is not enough to stop sshd.** Debian's `ssh.service` is triggered by `ssh.socket`, which independently listens on port 22 and spawns `sshd` on the next connection — regardless of the service's enabled/disabled state. You must stop *and* disable `ssh.socket` as well, or the real sshd will keep silently coming back.

## WireGuard

- **`AllowedIPs` is a hard packet filter, not just a routing hint.** Even with correct kernel routing tables (including custom policy-routing tables), WireGuard will silently drop any outbound packet whose destination address isn't covered by the relevant peer's `AllowedIPs`. If you need to reach arbitrary destinations through a peer (e.g. relaying to real attacker IPs), `AllowedIPs` must be widened to `0.0.0.0/0` — a narrower subnet will cause packets to vanish with no error, just timeouts.
- **`Table = off` matters once `AllowedIPs` is widened.** By default, `wg-quick` auto-installs a route based on `AllowedIPs` — with `0.0.0.0/0`, that would hijack *all* traffic through the tunnel. `Table = off` disables that auto-routing, letting you manage routing manually (e.g. via `PostUp`/`PreDown` policy-routing rules) so only the traffic you intend goes through the tunnel.
- **MASQUERADE hides real source IPs.** The simplest fix for asymmetric-routing connection failures across a tunnel is `MASQUERADE` on the relay's tunnel output — but this rewrites every packet's source to the tunnel's own address before it reaches the other end, meaning the receiving side (Cowrie, in this case) never sees genuine attacker IPs. If you need real source IPs preserved, use policy routing instead (see [step 5](05-wireguard-tunnel.md)).

## Loki / Promtail

- **Promtail was removed from Loki releases starting `v3.7.3`**, deprecated in favor of Grafana Alloy. If a "latest" download of `promtail-linux-amd64.zip` 404s, that's why — pin to an older tag like `v2.9.4` instead, which still speaks Loki's push API fine.
- **Pipeline stage output isn't sent to Loki automatically.** Stages like `geoip` compute fields internally for use by later stages, but nothing reaches Loki as an actual label unless a `labels:` stage explicitly promotes it afterward. This fails silently — no error, the fields are just absent downstream.

## Grafana

- **The Loki data source URL field can silently end up as `https://`.** If "Save & test" fails with `server gave HTTP response to HTTPS client` even though the field visibly shows `http://`, clear the field entirely and retype it rather than trusting the display.
- **Explore ≠ Dashboard panels for transforms.** Building a Geomap-driving query/transform pipeline in Explore doesn't reliably carry over the way it does in an actual saved dashboard panel — build the real thing in a panel, not Explore, if you're troubleshooting a visualization that isn't rendering as expected.
- **Plain log queries return one row per log line, not one row per unique value.** If you need one row per unique combination of fields (e.g. one row per attacker location, not one per raw event), switch to a metric query (`count_over_time(...)` etc.) with `sum by (...)`, and run it as an **Instant** query. A plain `{job="x"} | json` query will make "Labels to fields" and similar transforms look broken, when the actual issue is the query shape.
- **Geomap's Route layer only connects sequential rows** — it's built for GPS-track-style data (a series of points over time from one source), not per-row origin/destination pairs. Drawing a line between two arbitrary points (e.g. attacker → host) per row isn't supported by Route; the **Network** layer (Grafana 10.1+) is the intended tool for that instead.

## MaxMind

- A freshly generated license key returning `Invalid license key` via the `curl` download endpoint, while working fine for a manual browser download from the same account, may just be an intermittent API-side quirk rather than anything wrong with the key or account. If you hit this, download manually and transfer the file rather than continuing to debug the API path.
