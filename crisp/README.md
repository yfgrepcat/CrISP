# CRISP router and client network

## Architecture overview

CRISP is the head router of our enterprise. It's located behind `PE-site` and splits the site into three parts:

- Transit to `PE-site`: `120.0.39.0/31`
  - `PE-site:e1-4 = 120.0.39.0/31`
  - `CRISP:e1-1 = 120.0.39.1/31`

- DMZ VLAN: `120.0.40.0/24`
  - `CRISP:e1-2 = 120.0.40.1/24`
  - `ovpn-site = 120.0.40.2/24`
  - `reverse-proxy = 120.0.40.3/24`
  - `web-server = 120.0.40.4/24`

- Private services VLAN: `120.0.41.0/24`
  - `CRISP:e1-3 = 120.0.41.1/24`
  - `pbx = 120.0.41.5/24`
  - `dhcp-crisp = 120.0.41.10/24`
  - `radius = 120.0.41.11/24`

- Private client net: `10.12.30.0/24`
  - `CRISP:e1-4 = 10.12.30.1/24`
  - `CRISP-CLIENT` obtains a DHCP lease in `10.12.30.100-200/24`
  - `phone-crisp1 = 10.12.30.101/24`
  - `phone-crisp2 = 10.12.30.102/24`

The DHCP server lives in the DMZ and serves the private client net through the CRISP DHCP relay.

## DHCP behavior

`dhcp-crisp` uses `dnsmasq` and hands out:

- router: `10.12.30.1`
- DNS server: `120.0.36.1`
- lease pool: `10.12.30.100-200/24`

## Quick checks

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com 120.0.36.1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com
docker exec clab-enterprise-ospf-bgp-phone-crisp1 ip addr show eth1
docker exec clab-enterprise-ospf-bgp-phone-crisp2 ip addr show eth1
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
472: eth1@if471: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9500 qdisc noqueue state UP group default 
    link/ether aa:c1:ab:bf:ac:f3 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    altname clab-o-deaf4243a292129a
    inet 10.12.30.156/24 brd 10.12.30.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a8c1:abff:febf:acf3/64 scope link proto kernel_ll 
       valid_lft forever preferred_lft forever
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
default via 10.12.30.1 dev eth1 
10.12.30.0/24 dev eth1 proto kernel scope link src 10.12.30.156 
172.20.20.0/24 dev eth0 proto kernel scope link src 172.20.20.56 
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com 120.0.36.1
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3


t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3


t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-phone-crisp1 ip addr show eth1
458: eth1@if457: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9500 qdisc noqueue state UP group default 
    link/ether aa:c1:ab:a5:4a:87 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    altname clab-o-3f583952142f877d
    inet 10.12.30.101/24 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a8c1:abff:fea5:4a87/64 scope link 
       valid_lft forever preferred_lft forever
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-phone-crisp2 ip addr show eth1
407: eth1@if406: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9500 qdisc noqueue state UP group default 
    link/ether aa:c1:ab:58:28:e6 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    altname clab-o-3ff2f55f3493c847
    inet 10.12.30.102/24 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a8c1:abff:fe58:28e6/64 scope link 
       valid_lft forever preferred_lft forever
t70n@t70n-workstation:~/Documents/crisp$ 
```