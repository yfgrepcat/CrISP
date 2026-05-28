#!/usr/bin/env bash
# This script tears down the host bridges and deletes the VLAN subinterfaces created by the setup scripts.
#
# Requirements:
#   - Must be run as root.
#
# Environment variables:
#   VLAN_IFACE_PREFIX  : Prefix for VLAN subinterfaces to delete (default: clab).
#
# Usage:
#   sudo ./scripts/remove-host-bridges.sh

set -euo pipefail

BRIDGES=(
  net-isp
  dns-net
  dhcp-net
  net-nomad
  net-site
  net-crisp
  net-crisp-dmz
  net-crisp-srv
  net-crisp-cli
  net-home
  breakout-trunk
  br-vlan104
  br-vlan121
  br-vlan122
)

BREAKOUT_VLANS=(104 121 122)
VLAN_IFACE_PREFIX="${VLAN_IFACE_PREFIX:-clab}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root, for example: sudo $0" >&2
  exit 1
fi

for vlan in "${BREAKOUT_VLANS[@]}"; do
  vlan_iface="${VLAN_IFACE_PREFIX}${vlan}"

  if ip link show dev "$vlan_iface" >/dev/null 2>&1; then
    ip link set dev "$vlan_iface" down || true
    ip link delete dev "$vlan_iface"
    echo "Deleted VLAN interface '$vlan_iface'."
  else
    echo "VLAN interface '$vlan_iface' does not exist."
  fi
done

for bridge in "${BRIDGES[@]}"; do
  if ! ip link show dev "$bridge" >/dev/null 2>&1; then
    echo "Bridge '$bridge' does not exist."
    continue
  fi

  if [[ ! -d "/sys/class/net/$bridge/bridge" ]]; then
    echo "Interface '$bridge' exists but is not a bridge; skipping." >&2
    continue
  fi

  if [[ -d "/sys/class/net/$bridge/brif" ]]; then
    for port_path in "/sys/class/net/$bridge/brif/"*; do
      [[ -e "$port_path" ]] || continue
      port="$(basename "$port_path")"
      ip link set dev "$port" nomaster || true
      echo "Detached '$port' from '$bridge'."
    done
  fi

  ip link set dev "$bridge" down || true
  ip link delete dev "$bridge" type bridge
  echo "Deleted bridge '$bridge'."
done
