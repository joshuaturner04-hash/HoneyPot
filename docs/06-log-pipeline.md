# 6. Log pipeline: Cowrie → Promtail → Loki → Grafana

## Loki (on your monitoring host)

```bash
wget https://github.com/grafana/loki/releases/latest/download/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
mv loki-linux-amd64 /usr/local/bin/loki
chmod +x /usr/local/bin/loki
```

Minimal working config and a systemd service — see the [Loki docs](https://grafana.com/docs/loki/latest/) for the full config reference. Listens on `:3100` by default.

```bash
curl http://localhost:3100/ready
```

## Promtail (on the honeypot)

> **Version note:** Promtail was removed entirely as of Loki `v3.7.3`, deprecated in favor of Grafana Alloy. Pin to `v2.9.4` instead — it still speaks the same push API Loki expects:
>
> ```bash
> wget https://github.com/grafana/loki/releases/download/v2.9.4/promtail-linux-amd64.zip
> ```

See [`configs/promtail/config.yaml.example`](../configs/promtail/config.yaml.example) for the full config. Key points:

```yaml
pipeline_stages:
  - json:
      expressions:
        src_ip: src_ip
        eventid: eventid
        username: username
        password: password
  - geoip:
      db: /etc/promtail/GeoLite2-City.mmdb
      source: src_ip
      db_type: city
  - labels:
      geoip_city_name:
      geoip_country_name:
      geoip_country_code:
      geoip_location_latitude:
      geoip_location_longitude:
```

> **Gotcha:** pipeline stage output isn't automatically sent to Loki. The `geoip` stage computes fields internally, but they're discarded unless a `labels:` stage afterward explicitly promotes them to real Loki labels. Forgetting this stage means the enrichment silently does nothing — no error, just missing data downstream.

## GeoIP database

Get `GeoLite2-City.mmdb` from a free [MaxMind account](https://www.maxmind.com/en/geolite2/signup) (Account → Manage License Keys → Download Files).

> If the `curl`-based download with a license key returns `Invalid license key` even with a freshly generated, verified key, try downloading the file manually from the MaxMind dashboard in your browser instead — this worked when the API-based download didn't, for reasons that weren't fully diagnosed. Transfer the file to your honeypot container via your hypervisor's file-push tool (e.g. `pct push` for Proxmox) if the container itself isn't directly reachable.

## Cross-subnet firewall note

If your honeypot sits on an isolated subnet (per [step 1](01-network-isolation.md)) and your monitoring host is on the main LAN, Promtail's traffic to Loki needs an explicit allow rule on your router/hypervisor's forwarding chain — the isolation is working as intended otherwise.

```bash
# on the Proxmox host
iptables -I FORWARD -s <honeypot-subnet> -d <monitoring-host-ip> -p tcp --dport 3100 -j ACCEPT
netfilter-persistent save
```

## Verify data is flowing

```bash
curl -G -s "http://<monitoring-host-ip>:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="cowrie", geoip_location_latitude=~".+"}' \
  --data-urlencode "start=$(date -d '10 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" | grep -o '"geoip_[^"]*":"[^"]*"'
```

You should see populated `geoip_city_name`, `geoip_location_latitude`, etc.

Next: [7. Grafana dashboard →](07-grafana-dashboard.md)
