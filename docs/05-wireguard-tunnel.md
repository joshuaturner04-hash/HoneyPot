# 5. WireGuard tunnel (the CGNAT workaround)

If your home ISP uses CGNAT, there's no public IP to forward a port to — port forwarding on your router does nothing. The fix: run a cheap VPS with a real public IP, and tunnel traffic from it back to the honeypot with WireGuard.

## Get a VPS

Any provider works. Cheapest shared-CPU tier is plenty (1 vCPU / 1GB RAM) — this is just relaying a tunnel.

## Install WireGuard on both ends

```bash
apt install -y wireguard
```

## Generate keypairs (both sides)

```bash
cd /etc/wireguard
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
```

## Config: honeypot side

See [`configs/wireguard/honeypot.wg0.conf.example`](../configs/wireguard/honeypot.wg0.conf.example).

Key points:
- `AllowedIPs = 0.0.0.0/0` on the peer — **not** just the tunnel subnet
- `Table = off` — stops `wg-quick` auto-installing a default route from that wide `AllowedIPs`
- `PostUp`/`PreDown` — manual policy routing so reply traffic goes back through the tunnel

## Config: VPS side

See [`configs/wireguard/vps.wg0.conf.example`](../configs/wireguard/vps.wg0.conf.example).

## Bring both up

```bash
wg-quick up wg0
wg show   # confirm a recent "latest handshake" on both sides
```

## Move the VPS's own SSH off port 22

Port 22 is about to be forwarded to the honeypot — the VPS needs its own management access elsewhere first, or you'll lock yourself out.

```bash
# /etc/ssh/sshd_config
Port 2200
```

```bash
ufw allow 2200/tcp
systemctl restart ssh
```

**Test the new port in a separate session before closing your current one.**

## DNAT: forward public :22 to the honeypot through the tunnel

In UFW's `before.rules`, **above** the `*filter` block:

```
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -i <public-iface> -p tcp --dport 22 -j DNAT --to-destination 10.200.200.2:22
COMMIT
```

```bash
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
ufw allow 22/tcp
ufw allow 51820/udp
ufw reload
```

## The real-IP problem (and why `AllowedIPs = 0.0.0.0/0` matters)

A naive DNAT setup will fail with connection timeouts — the honeypot doesn't know how to route reply packets back to the attacker's real IP, since its default route only knows about the local LAN. The common "fix" is `MASQUERADE` on the VPS's tunnel output, rewriting the attacker's IP to the tunnel's internal address before forwarding. **This works, but hides the real attacker IP from Cowrie's logs** — every session will show the tunnel IP instead.

The actual fix used here:

1. **No MASQUERADE.** Real IPs are preserved end-to-end.
2. **Policy routing on the honeypot** so replies destined for any real internet IP get routed back out through `wg0` (see the `PostUp`/`PreDown` lines in the honeypot's config).
3. **`AllowedIPs = 0.0.0.0/0`** on the honeypot's peer. This one is easy to miss: even with correct kernel routing tables, **WireGuard itself silently drops any outbound packet whose destination isn't covered by the peer's `AllowedIPs`** — it's a WireGuard-level filter, separate from the OS routing table. If `AllowedIPs` is left as just the tunnel subnet (e.g. `10.200.200.0/24`), replies to real attacker IPs get dropped before they even reach the wire, with no error message — just a timeout.

## Test

From a network that is **not** your home network (mobile data, a friend's connection):

```bash
ssh -p 22 root@<vps-public-ip>
```

Then check the honeypot's log — `src_ip` should show the real external IP, not the tunnel address:

```bash
tail -5 /home/cowrie/cowrie/var/log/cowrie/cowrie.json
```

See [`scripts/test-tunnel.sh`](../scripts/test-tunnel.sh) for a quick automated check of both ends.

Next: [6. Log pipeline →](06-log-pipeline.md)
