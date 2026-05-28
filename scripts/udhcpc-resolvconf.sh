#!/bin/sh
# This script acts as a configuration/resolvconf handler for udhcpc (busybox DHCP client).
# It configures the IP address, subnet mask, default gateway, and updates /etc/resolv.conf 
# based on parameters provided by the DHCP server.
#
# Usage:
#   This script is invoked by udhcpc with arguments: bound, renew, deconfig, leasefail, nak
#   Environment variables like $interface, $ip, $mask, $router, $dns, $search, $domain are set by udhcpc.

set -eu

RESOLV_CONF=${RESOLV_CONF:-/etc/resolv.conf}

configure_interface() {
  local prefix_len gateway

  prefix_len=$mask
  case "$mask" in
    255.255.255.255) prefix_len=32 ;;
    255.255.255.0) prefix_len=24 ;;
    255.255.0.0) prefix_len=16 ;;
    255.0.0.0) prefix_len=8 ;;
  esac

  ip -4 addr flush dev "$interface" || true
  ip -4 addr add "$ip/$prefix_len" ${broadcast:+broadcast "$broadcast"} dev "$interface"
  ip -4 link set dev "$interface" up

  while ip -4 route del default dev "$interface" 2>/dev/null; do
    :
  done

  for gateway in ${router:-}; do
    ip -4 route add default via "$gateway" dev "$interface"
    break
  done
}

write_resolv_conf() {
  : > "$RESOLV_CONF"

  if [ -n "${search:-}" ]; then
    echo "search $search" >> "$RESOLV_CONF"
  elif [ -n "${domain:-}" ]; then
    echo "search $domain" >> "$RESOLV_CONF"
  fi

  for nameserver in ${dns:-}; do
    echo "nameserver $nameserver" >> "$RESOLV_CONF"
  done

  if [ ! -s "$RESOLV_CONF" ]; then
    echo "nameserver 127.0.0.1" >> "$RESOLV_CONF"
  fi
}

case "${1:-}" in
  bound|renew)
    configure_interface
    write_resolv_conf
    ;;
  deconfig)
    ip -4 addr flush dev "$interface" 2>/dev/null || true
    : > "$RESOLV_CONF"
    ;;
  leasefail|nak)
    exit 0
    ;;
  *)
    echo "Usage: $0 {bound|renew|deconfig|leasefail|nak}" >&2
    exit 1
    ;;
esac