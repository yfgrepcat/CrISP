# CRISP addressing and tests

## Exact IP plan

### PE-site to CRISP transit

- `PE-site:e1-4 = 120.0.39.0/31`
- `CRISP:e1-1 = 120.0.39.1/31`

### CRISP DMZ

- `CRISP:e1-2 = 120.0.40.1/24`
- `ovpn-site = 120.0.40.2/24`
- `reverse-proxy = 120.0.40.3/24`
- `web-server = 120.0.40.4/24`
- `pbx = 120.0.40.5/24`
- `dhcp-crisp = 120.0.40.10/24`

### CRISP private client network

- `CRISP:e1-3 = 10.12.30.1/24`
- `CRISP-CLIENT = DHCP from 10.12.30.100-10.12.30.200`
- `phone-crisp1 = 10.12.30.101/24`
- `phone-crisp2 = 10.12.30.102/24`

## Services

- Web server service IP: `120.0.40.4`
- VoIP PBX service IP: `120.0.40.5`
- DHCP server service IP: `120.0.40.10`
- DNS server used for lookups: `120.0.36.1`

## Web reachability tests from CRISP

Use `CRISP-CLIENT` for both IP and DNS checks:

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: extranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Connexion Intranet"'
```

## DHCP checks

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.40.10
docker exec clab-enterprise-ospf-bgp-dhcp-crisp ps aux | grep dnsmasq
docker exec clab-enterprise-ospf-bgp-dhcp-crisp cat /var/lib/misc/dnsmasq.leases
```

## Notes

- The CRISP DMZ is the only place where the web, VPN, VoIP, and DHCP services live.
- The private client net is behind `CRISP` and receives its leases through DHCP relay.
- The CRISP client bridge name is shortened to `net-crisp-cli` because Linux interface names must stay 15 characters or fewer.
