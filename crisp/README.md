# CRISP router and client network

## Architecture overview

CRISP is the head router behind `PE-site` and splits the site into two parts:

- Transit to `PE-site`: `120.0.39.0/31`
  - `PE-site:e1-4 = 120.0.39.0/31`
  - `CRISP:e1-1 = 120.0.39.1/31`
- DMZ VLAN: `120.0.40.0/24`
  - `CRISP:e1-2 = 120.0.40.1/24`
  - `ovpn-site = 120.0.40.2/24`
  - `reverse-proxy = 120.0.40.3/24`
  - `web-server = 120.0.40.4/24`
  - `PBX and DHCP` moved to the private services VLAN
- Private services VLAN: `120.0.41.0/24`
  - `CRISP:e1-3 = 120.0.41.1/24`
  - `pbx = 120.0.41.5/24`
  - `dhcp-crisp = 120.0.41.10/24`
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
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.40.10
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com 120.0.36.1
docker exec clab-enterprise-ospf-bgp-phone-crisp1 ip addr show eth1
docker exec clab-enterprise-ospf-bgp-phone-crisp2 ip addr show eth1
```
