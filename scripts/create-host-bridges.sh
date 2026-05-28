#!/usr/bin/env bash
# This script creates the Linux host bridges and sets up the VLAN subinterfaces
# needed by Containerlab to connect simulated network topologies to physical interfaces.
#
# Requirements:
#   - Must be run as root.
#
# Environment variables:
#   TRUNK_IFACE        : Host interface connected to the physical switch trunk (for VLAN-backed breakout).
#   RAW_TRUNK_IFACE    : Host interface for raw trunk connections.
#   P4_TRANSPORT_IFACE : Host interface for P4 transport.
#   P4_TRANSPORT_VLAN  : VLAN ID used for P4 transport (default: 104).
#   VLAN_IFACE_PREFIX  : Prefix for created VLAN subinterfaces (default: clab).
#
# Usage:
#   sudo ./scripts/create-host-bridges.sh
#   TRUNK_IFACE=<host-nic> sudo -E ./scripts/create-host-bridges.sh

set -euo pipefail

BRIDGES=(
  net-isp
  dns-net
  dhcp-net
  net-nomad
  net-site
  net-crisp-dmz
  net-crisp-srv
  net-crisp-cli
  net-home
  breakout-trunk
  br-vlan121
  br-vlan122
)

BREAKOUT_VLANS=(121 122)
TRUNK_IFACE="${TRUNK_IFACE:-}"
RAW_TRUNK_IFACE="${RAW_TRUNK_IFACE:-}"
P4_TRANSPORT_IFACE="${P4_TRANSPORT_IFACE:-$TRUNK_IFACE}"
P4_TRANSPORT_VLAN="${P4_TRANSPORT_VLAN:-104}"
VLAN_IFACE_PREFIX="${VLAN_IFACE_PREFIX:-clab}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root, for example: TRUNK_IFACE=<host-nic> sudo -E $0" >&2
  exit 1
fi

for bridge in "${BRIDGES[@]}"; do
  if ip link show dev "$bridge" >/dev/null 2>&1; then
    if ! ip -d link show dev "$bridge" | grep -q "^[[:space:]]*bridge "; then
      echo "Interface '$bridge' already exists but is not a bridge." >&2
      exit 1
    fi
    echo "Bridge '$bridge' already exists."
  else
    ip link add name "$bridge" type bridge
    echo "Created bridge '$bridge'."
  fi

  ip link set dev "$bridge" up
done

if [[ -n "$RAW_TRUNK_IFACE" ]]; then
  if ! ip link show dev "$RAW_TRUNK_IFACE" >/dev/null 2>&1; then
    echo "Interface '$RAW_TRUNK_IFACE' was not found." >&2
    exit 1
  fi

  ip link set dev "$RAW_TRUNK_IFACE" up
  ip link set dev "$RAW_TRUNK_IFACE" master breakout-trunk
  echo "Attached raw trunk interface '$RAW_TRUNK_IFACE' to 'breakout-trunk'."
fi

if [[ -n "$P4_TRANSPORT_IFACE" ]]; then
  if ! ip link show dev "$P4_TRANSPORT_IFACE" >/dev/null 2>&1; then
    echo "Interface '$P4_TRANSPORT_IFACE' was not found." >&2
    exit 1
  fi

  p4_vlan_iface="${VLAN_IFACE_PREFIX}${P4_TRANSPORT_VLAN}"
  ip link set dev "$P4_TRANSPORT_IFACE" up

  if ip link show dev "$p4_vlan_iface" >/dev/null 2>&1; then
    echo "VLAN interface '$p4_vlan_iface' already exists."
  else
    ip link add link "$P4_TRANSPORT_IFACE" name "$p4_vlan_iface" type vlan id "$P4_TRANSPORT_VLAN"
    echo "Created VLAN interface '$p4_vlan_iface'."
  fi

  ip link set dev "$p4_vlan_iface" up
  ip link set dev "$p4_vlan_iface" master breakout-trunk
  echo "Attached '$p4_vlan_iface' to 'breakout-trunk' for P4 transport VLAN $P4_TRANSPORT_VLAN."
fi

if [[ -n "$TRUNK_IFACE" ]]; then
  if ! ip link show dev "$TRUNK_IFACE" >/dev/null 2>&1; then
    echo "Interface '$TRUNK_IFACE' was not found." >&2
    exit 1
  fi

  ip link set dev "$TRUNK_IFACE" up

  for vlan in "${BREAKOUT_VLANS[@]}"; do
    vlan_iface="${VLAN_IFACE_PREFIX}${vlan}"
    bridge="br-vlan${vlan}"

    if ip link show dev "$vlan_iface" >/dev/null 2>&1; then
      echo "VLAN interface '$vlan_iface' already exists."
    else
      ip link add link "$TRUNK_IFACE" name "$vlan_iface" type vlan id "$vlan"
      echo "Created VLAN interface '$vlan_iface'."
    fi

    ip link set dev "$vlan_iface" up
    ip link set dev "$vlan_iface" master "$bridge"
    echo "Attached '$vlan_iface' to '$bridge'."
  done
else
  echo "TRUNK_IFACE is not set; skipped VLAN-backed breakout ports." >&2
fi

ip -br link show "${BRIDGES[@]}"
