#!/usr/bin/env bash
#
# setup-bridge.sh — create the isolated honeypot bridge on a Proxmox host.
#
# Run this ON THE PROXMOX HOST, as root. Review before running —
# this edits /etc/network/interfaces and reloads networking.
#
# Usage: ./setup-bridge.sh <bridge-name> <subnet-cidr> <uplink-bridge>
# Example: ./setup-bridge.sh honeypot0 10.97.0.1/24 vmbr0

set -euo pipefail

BRIDGE_NAME="${1:?Usage: $0 <bridge-name> <subnet-cidr> <uplink-bridge>}"
SUBNET_CIDR="${2:?Usage: $0 <bridge-name> <subnet-cidr> <uplink-bridge>}"
UPLINK="${3:?Usage: $0 <bridge-name> <subnet-cidr> <uplink-bridge>}"

SUBNET_BASE="${SUBNET_CIDR%.*}.0/24"

echo ">> Adding bridge ${BRIDGE_NAME} (${SUBNET_CIDR}) to /etc/network/interfaces"
cat >> /etc/network/interfaces <<EOF

auto ${BRIDGE_NAME}
iface ${BRIDGE_NAME} inet static
    address ${SUBNET_CIDR}
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

echo ">> Reloading network config"
ifreload -a

echo ">> Enabling IP forwarding"
echo 1 > /proc/sys/net/ipv4/ip_forward
grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

echo ">> Adding outbound NAT for ${SUBNET_BASE} via ${UPLINK}"
iptables -t nat -A POSTROUTING -s "${SUBNET_BASE}" -o "${UPLINK}" -j MASQUERADE
apt install -y iptables-persistent >/dev/null
netfilter-persistent save

echo ">> Done. Verify with:"
echo "   ip link show ${BRIDGE_NAME}"
echo "   brctl show ${BRIDGE_NAME}"
