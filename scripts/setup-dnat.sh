#!/usr/bin/env bash
#
# setup-dnat.sh — configure the VPS-side DNAT that forwards public :22
# through the WireGuard tunnel to the honeypot.
#
# Run this ON THE VPS, as root, AFTER:
#   1. Moving the VPS's own sshd to a different port (e.g. 2200)
#   2. Confirming the WireGuard tunnel is up (wg show shows a handshake)
#
# Usage: ./setup-dnat.sh <public-iface> <tunnel-dest-ip>
# Example: ./setup-dnat.sh enp1s0 10.200.200.2

set -euo pipefail

PUBLIC_IFACE="${1:?Usage: $0 <public-iface> <tunnel-dest-ip>}"
TUNNEL_DEST="${2:?Usage: $0 <public-iface> <tunnel-dest-ip>}"

BEFORE_RULES="/etc/ufw/before.rules"

if grep -q "DNAT --to-destination ${TUNNEL_DEST}:22" "${BEFORE_RULES}"; then
  echo ">> DNAT rule already present in ${BEFORE_RULES}, skipping insert."
else
  echo ">> Inserting *nat block at the top of ${BEFORE_RULES}"
  TMP=$(mktemp)
  cat > "${TMP}" <<EOF
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -i ${PUBLIC_IFACE} -p tcp --dport 22 -j DNAT --to-destination ${TUNNEL_DEST}:22
COMMIT
EOF
  cat "${BEFORE_RULES}" >> "${TMP}"
  mv "${TMP}" "${BEFORE_RULES}"
fi

echo ">> Enabling UFW forwarding"
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

echo ">> Allowing port 22 through UFW"
ufw allow 22/tcp

echo ">> Reloading UFW"
ufw reload

echo ">> Verifying the rule loaded into the kernel:"
iptables -t nat -L PREROUTING -n -v | grep -A1 "target.*prot"

echo ""
echo ">> NOTE: do not enable MASQUERADE on the wg0 interface if you want"
echo "   real attacker IPs preserved in Cowrie's logs — see docs/gotchas.md"
