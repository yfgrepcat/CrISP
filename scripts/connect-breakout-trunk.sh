#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${TRUNK_IFACE:-}" ]]; then
  echo "Set TRUNK_IFACE to the host NIC connected to the physical switch trunk." >&2
  echo "Example: TRUNK_IFACE=enp195s0f3u1 sudo -E $0" >&2
  exit 1
fi

exec "$SCRIPT_DIR/create-host-bridges.sh"
