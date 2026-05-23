# DNS service

## Architecture overview

The DNS server is `dns-as12` (BIND9) connected to router `P2`.

- DNS container name: `clab-enterprise-ospf-bgp-dns-as12`
- DNS mgmt IP: `172.20.20.30`
- DNS service IP: `120.0.34.7`

The BIND config is split by views in `dns/views.conf`.

## Views and ACL behavior

View selection depends on source IP (client subnet):

- Enterprise ACL: `120.0.37.0/24`
- Residential ACL: `120.0.38.0/24`
- Default view: all other sources

Important: view selection is source-IP based, so answers can change depending on client address.

## Effective records in this topology

For `enterprise.local`:

- `www.enterprise.local` -> `120.0.35.11` for enterprise view
- `www.enterprise.local` -> `120.0.35.12` for residential view
- `voip.enterprise.local` -> `120.0.35.13` in both views

For `corentinpradier.com`:

- `extranet.corentinpradier.com` -> `172.20.20.34` (public + enterprise/residential)
- `intranet.corentinpradier.com` -> `172.20.20.34` (enterprise/residential only)
- `voip.corentinpradier.com` -> `120.0.35.1`

Note: there is no apex `A` record for `corentinpradier.com` in the current zone files. Use `extranet.corentinpradier.com` and `intranet.corentinpradier.com` for web checks.

## Quick rebuild

From repo root:

```bash
sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## Quick host checks

```bash
dig @172.20.20.30 www.enterprise.local +short
dig @172.20.20.30 voip.enterprise.local +short
dig @172.20.20.30 extranet.corentinpradier.com +short
dig @172.20.20.30 intranet.corentinpradier.com +short
```

## View test (enterprise vs residential)

Run from the DNS container by creating temporary dummy source IPs inside the real ACL subnets.

```bash
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add ent0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 120.0.37.10/24 dev ent0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set ent0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add res0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 120.0.38.10/24 dev res0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set res0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 120.0.37.10 @120.0.34.7 www.enterprise.local +short
docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 120.0.38.10 @120.0.34.7 www.enterprise.local +short
```

Expected:

- Source `120.0.37.10` returns `120.0.35.11`
- Source `120.0.38.10` returns `120.0.35.12`

Cleanup:

```bash
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link del ent0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link del res0
```

## Realistic client-side checks

Use containers that already rely on DNS in this lab:

```bash
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'nslookup extranet.corentinpradier.com 172.20.20.30'
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 172.20.20.30'
```

Optional HTTP checks through reverse proxy:

```bash
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'wget -qO- --header="Host: extranet.corentinpradier.com" http://172.20.20.34 | head -c 200'
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://172.20.20.34 | head -c 200'
```

## Debug commands

```bash
docker ps --filter "name=dns-as12" --format "{{.Names}}"
docker exec -it clab-enterprise-ospf-bgp-dns-as12 sh

# inside container
named-checkconf /etc/bind/named.conf
named-checkzone enterprise.local /etc/bind/zones/db.enterprise.local
named-checkzone enterprise.local /etc/bind/zones/db.enterprise.local.residential
named-checkzone corentinpradier.com /etc/bind/zones/db.corentinpradier.com
```

For runtime logs, use container logs from the host:

```bash
docker logs clab-enterprise-ospf-bgp-dns-as12 | tail -n 100
```