#!/bin/sh
set -e

# 1. Install required packages 
# Note: In a production environment, these would be in a custom Docker image.
# We install them here for transparency and flexibility in this lab.
apk add --no-cache iproute2 iptables dnsmasq

# 2. Configure WAN Interface (eth1) via AS DHCP
echo "Configuring WAN (eth1)..."
ip link set eth1 up
udhcpc -i eth1 -q

# 3. Clean up default management route to force traffic through AS fabric
echo "Removing management default route..."
ip route del default via 172.20.20.1 || true

# 4. Configure LAN Interface (eth2)
echo "Configuring LAN (eth2)..."
ip link set eth2 up
ip addr add 192.168.1.1/24 dev eth2

# 5. Enable IP Forwarding and NAT (Masquerade)
echo "Enabling NAT..."
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

# 6. Start DHCP/DNS Service
echo "Starting DHCP services..."
exec dnsmasq --no-daemon --conf-file=/etc/dnsmasq.conf
