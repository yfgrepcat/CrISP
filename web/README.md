# Web service

Simple web architecture with one reverse proxy and one backend web server.

## How it works

- `reverse-proxy` is the entry point.
- Public hostname: `extranet.corentinpradier.com` (public page).
- Intranet hostname: `intranet.corentinpradier.com` (restricted by source subnet).
- Backend content is served by `web-server`:
  - public site on port `80`
  - intranet site on port `6767`

In this topology:

- Reverse proxy mgmt IP: `172.20.20.34`
- Reverse proxy service-side IP: `120.0.40.3/24`
- Web server IP: `120.0.40.4/24`
- DNS server for tests: `120.0.36.1`

## Build and deploy

From repo root:

```bash
docker build -t reverse-proxy:latest ./web/reverse-proxy
docker build -t web:latest ./web

sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## Tests

### Public website

The public site should be reachable by IP and by DNS.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: extranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
```

### Intranet website

The intranet site should be reachable only from allowed enterprise/private ranges.

```bash
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Connexion Intranet"'
```

## Quick debug

```bash
docker logs clab-enterprise-ospf-bgp-reverse-proxy | tail -n 100
docker logs clab-enterprise-ospf-bgp-web-server | tail -n 100
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com 120.0.36.1'
```