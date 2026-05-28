#!/usr/bin/env bash
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
  br-vlan104
  br-vlan121
  br-vlan122
)

BREAKOUT_VLANS=(104 121 122)
TRUNK_IFACE="${TRUNK_IFACE:-}"
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
  echo "TRUNK_IFACE is not set; created bridges only. Set TRUNK_IFACE to create VLAN-backed breakout ports." >&2
fi

ip -br link show "${BRIDGES[@]}"
