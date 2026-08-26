# 4. Redirect real port 22 → Cowrie

Cowrie listens on `2222` by default (running as non-root is safer). To look like a normal SSH server, redirect the container's real port 22.

## Disable the real sshd — including its socket

Debian's `ssh` service uses socket activation. Stopping/disabling `ssh.service` alone is **not enough** — `ssh.socket` will silently respawn `sshd` on the next connection attempt.

```bash
systemctl stop ssh.socket
systemctl disable ssh.socket
systemctl stop ssh
systemctl disable ssh
```

Confirm both are inactive:

```bash
systemctl status ssh.socket ssh
```

## Redirect port 22 → 2222

```bash
iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port 2222
apt install -y iptables-persistent
netfilter-persistent save
```

Check the rule loaded (should show exactly one, packet/byte counters increasing on connections):

```bash
iptables -t nat -L PREROUTING -n -v
```

## Test

```bash
ssh -p 22 root@10.97.0.10
```

Any password should now drop you into Cowrie's fake shell.

Next: [5. WireGuard tunnel →](05-wireguard-tunnel.md)
