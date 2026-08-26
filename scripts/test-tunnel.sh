#!/usr/bin/env bash
#
# test-tunnel.sh — sanity-check the WireGuard tunnel and Cowrie's
# ability to see real attacker IPs.
#
# Run on EITHER end. Reports:
#   - whether wg0 is up and has a recent handshake
#   - whether the honeypot's log shows genuine external IPs
#     (i.e. anything other than the tunnel's own 10.200.200.0/24 range)

set -uo pipefail

echo "== WireGuard status =="
if ! command -v wg >/dev/null; then
  echo "wg command not found — is wireguard-tools installed?"
  exit 1
fi

wg show

LATEST_HANDSHAKE=$(wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}')
if [[ -z "${LATEST_HANDSHAKE}" || "${LATEST_HANDSHAKE}" == "0" ]]; then
  echo ""
  echo "⚠️  No handshake recorded yet. Check:"
  echo "   - Firewall allows UDP 51820 inbound on the VPS"
  echo "   - Both sides' public keys match what's configured as the peer"
  echo "   - PersistentKeepalive is set if either side is behind NAT"
else
  echo ""
  echo "✅ Handshake looks healthy."
fi

COWRIE_LOG="/home/cowrie/cowrie/var/log/cowrie/cowrie.json"
if [[ -f "${COWRIE_LOG}" ]]; then
  echo ""
  echo "== Recent src_ip values in Cowrie's log =="
  tail -n 50 "${COWRIE_LOG}" | grep -o '"src_ip":"[^"]*"' | sort -u

  echo ""
  if tail -n 50 "${COWRIE_LOG}" | grep -q '"src_ip":"10\.200\.200\.'; then
    echo "⚠️  Some recent sessions show the tunnel's internal IP, not a real"
    echo "   external address. If this is unexpected, check:"
    echo "   - MASQUERADE is NOT applied to the wg0 interface on the VPS"
    echo "   - AllowedIPs on the honeypot peer is 0.0.0.0/0, not just the"
    echo "     tunnel subnet"
    echo "   - The PostUp policy-routing rules are actually applied"
    echo "     (check: ip rule list / ip route show table 51820)"
  else
    echo "✅ No tunnel-internal IPs seen in recent log lines — looks like"
    echo "   real external IPs are being captured correctly."
  fi
else
  echo ""
  echo "Cowrie log not found at ${COWRIE_LOG} — run this on the honeypot host,"
  echo "or adjust the path in this script."
fi
