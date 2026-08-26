# 7. Grafana dashboard

## Add Loki as a data source

Connections → Data sources → Add data source → Loki.

URL: `http://localhost:3100` (if Grafana and Loki share a host).

> **Gotcha:** if "Save & test" fails with something like `http: server gave HTTP response to HTTPS client`, the URL field has silently ended up as `https://` instead of `http://` — clear the field completely and retype it manually rather than trusting what's shown, some browsers/autofill can mangle this.

## Build the Geomap panel

Build this as an actual **Dashboard panel**, not in **Explore** — Explore's transform pipeline doesn't reliably drive a Geomap visualization the same way a saved panel does.

Dashboards → New → Add visualization → select Loki.

### Query

This is the part that took the most trial and error. A plain log query like `{job="cowrie", geoip_location_latitude=~".+"}` returns **one row per raw log line** — which means "Labels to fields" and the Geomap panel only ever see a single collapsed/repeated series, not one row per distinct attacker location.

The fix: use a **metric query** with `count_over_time`, and make sure it's evaluated as an **Instant** query (Grafana surfaces an Instant/Range choice once the query is metric-shaped, which it doesn't for plain log queries):

```logql
sum by (geoip_location_latitude, geoip_location_longitude, geoip_city_name, geoip_country_name)
  (count_over_time({job="cowrie", geoip_location_latitude=~".+"}[$__range]))
```

Grouping explicitly by the geoip fields with `sum by (...)` ensures each unique location gets its own row, rather than being merged into a single time-series.

### Transforms

1. **Labels to fields** — Mode: Columns, leave the Labels field empty (converts every label into a column).
2. **Convert field type** — set `geoip_location_latitude` and `geoip_location_longitude` to type **Number** (they arrive as strings from Loki).

> If `geoip_location_latitude` doesn't show up in the "Convert field type" field dropdown, it usually means the *query* result shape is wrong (still a raw log query, or still Range instead of Instant) rather than a real UI bug — recheck the query above before assuming the transform is broken.

### Panel settings

- Visualization type: **Geomap**
- Location mode: **Coords**
- Latitude field: `geoip_location_latitude`
- Longitude field: `geoip_location_longitude`

## Verifying multiple markers show up

Widen the time range (top right) if you only see one point — but if the table view (toggle at the top of the query editor) also only shows one row across many *timestamps* for the same location, that's the Range-vs-Instant issue above, not a time-range problem.

Next: [Gotchas & lessons learned →](gotchas.md)
