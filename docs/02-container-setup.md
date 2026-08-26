# 2. Container setup

An **unprivileged** LXC is important here — if Cowrie or the underlying kernel is ever exploited, the container's root is not the host's root.

## Grab a Debian 12 template

```bash
pveam update
pveam available | grep debian-12
pveam download local debian-12-standard_<version>_amd64.tar.zst
```

Use the plain `debian-12-standard_*` template — not one of the TurnKey Linux appliance variants also listed.

## Create the container

```bash
pct create <vmid> local:vztmpl/debian-12-standard_<version>_amd64.tar.zst \
  --hostname honeypot-01 \
  --cores 2 \
  --memory 1024 \
  --swap 512 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=honeypot0,ip=10.97.0.10/24,gw=10.97.0.1 \
  --unprivileged 1 \
  --features nesting=0 \
  --onboot 1
```

- Check `pct list` first to confirm `<vmid>` isn't already taken.
- Check `pvesm status` to confirm your storage name (`local-lvm` here — swap if you use ZFS or another pool).
- 2 vCPU / 1GB RAM / 8GB disk is comfortably enough for Cowrie alone.

## Start and enter

```bash
pct start <vmid>
pct enter <vmid>
```

Next: [3. Cowrie install →](03-cowrie-install.md)
