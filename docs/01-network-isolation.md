# 1. Network isolation

The honeypot must have **no route to the real home LAN**, even if the container itself is fully compromised. This is done with a dedicated Linux bridge that has no physical port and no gateway to anything else.

## Create the bridge

On the Proxmox host:

```bash
nano /etc/network/interfaces
```

```
auto honeypot0
iface honeypot0 inet static
    address 10.97.0.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Apply without rebooting:

```bash
ifreload -a
```

> You can name the bridge anything, but Proxmox's web UI only lets you *edit* bridges named `vmbrNN` visually — a custom name like `honeypot0` still works fine, you just manage it via `/etc/network/interfaces` directly instead of the GUI.

## Enable forwarding + outbound NAT

The honeypot needs outbound internet (updates, realism) but no inbound path except what you explicitly forward later.

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

iptables -t nat -A POSTROUTING -s 10.97.0.0/24 -o <your-uplink-bridge> -j MASQUERADE
apt install -y iptables-persistent
netfilter-persistent save
```

Replace `<your-uplink-bridge>` with whatever bridge actually has your default route (check with `ip route | grep default`).

## Sanity check

```bash
ip link show honeypot0
brctl show honeypot0
```

You should see the bridge `UP`, with **no interfaces attached** yet (nothing bridged to it until the container is created).

Next: [2. Container setup →](02-container-setup.md)
