# CRISP router and client network

This DHCP server is for the CRISP private client net. The CRISP router relays the requests from `10.12.30.0/24` here, and dnsmasq sends back the address, router, and DNS.

`dhcp-crisp` uses `dnsmasq` and hands out:
- router: `10.12.30.1`
- DNS server: `120.0.36.1`
- lease pool: `10.12.30.100-200/24`

## Architecture overview

CRISP is the head router of our enterprise. It's located behind `PE-site` and splits the site into three parts:

- Transit to `PE-site`: `120.0.39.0/31`
  - `PE-site = 120.0.39.0/31`
  - `CRISP = 120.0.39.1/31`

- DMZ VLAN: `120.0.40.0/24`
  - `CRISP = 120.0.40.1/24`
  - `ovpn-site = 120.0.40.2/24`
  - `reverse-proxy = 120.0.40.3/24`
  - `web-server = 120.0.40.4/24`

- Private services VLAN: `120.0.41.0/24`
  - `CRISP = 120.0.41.1/24`
  - `pbx = 120.0.41.5/24`
  - `dhcp-crisp = 120.0.41.10/24`
  - `radius = 120.0.41.11/24`

- Private client net: `10.12.30.0/24`
  - `CRISP = 10.12.30.1/24`
  - `CRISP-CLIENT` obtains a DHCP lease in `10.12.30.100-200/24`

The DHCP server lives in the DMZ and serves the private client net through the CRISP DHCP relay.

## CRISP DHCP service

CRISP also has a small DHCP server in the DMZ for the private client net.
- CRISP DHCP container: `dhcp-crisp`
- CRISP DHCP IP: `120.0.40.10/24`
- CRISP clients subnet served through relay: `10.12.30.0/24`
- Lease pool: `10.12.30.100-10.12.30.200/24`
- Router handed to clients: `10.12.30.1`
- DNS handed to clients: `120.0.36.1`

The CRISP router relays DHCP on `e1-3` from the private client net to the DMZ server at `120.0.40.10`.

## Quick checks

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.41.10
docker exec clab-enterprise-ospf-bgp-dhcp-crisp cat /var/lib/misc/dnsmasq.leases
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
89: eth1@if88: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9500 qdisc noqueue state UP group default 
    link/ether aa:c1:ab:63:89:53 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    altname clab-o-deaf4243a292129a
    inet 10.12.30.136/24 brd 10.12.30.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a8c1:abff:fe63:8953/64 scope link proto kernel_ll 
       valid_lft forever preferred_lft forever

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
default via 10.12.30.1 dev eth1 
10.12.30.0/24 dev eth1 proto kernel scope link src 10.12.30.136 
172.20.20.0/24 dev eth0 proto kernel scope link src 172.20.20.56 

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.41.10
PING 120.0.41.10 (120.0.41.10): 56 data bytes
64 bytes from 120.0.41.10: seq=0 ttl=63 time=0.535 ms
64 bytes from 120.0.41.10: seq=1 ttl=63 time=0.492 ms
64 bytes from 120.0.41.10: seq=2 ttl=63 time=0.318 ms

--- 120.0.41.10 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.318/0.448/0.535 ms

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dhcp-crisp cat /var/lib/misc/dnsmasq.leases
1780211238 aa:c1:ab:63:89:53 10.12.30.136 * 01:aa:c1:ab:63:89:53
```

We can see that CRISP-CLIENT do get an adress IP and can access DNS. Also, it's default route is via 10.12.30.1, just like we wanted to. It works ! 
Please note that phone-crisp1 and phone-crisp2 have static address IP.