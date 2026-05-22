# Enterprise Network

## First launch

```bash
chmod +x set_bridges
./set_bridges

docker build -t reverse-proxy:latest ./reverse-proxy
docker build -t web:latest ./web

cd voip-lab
make build
cd ..

sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## Restart after a reboot

```bash
./set_bridges
sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## DHCP service

The central DHCP server runs in `clab-enterprise-ospf-bgp-dhcp` and serves the local pool plus the relayed enterprise and private ranges.

Rebuild the lab from scratch when you want to validate DHCP end to end:

```bash
sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

Confirm the DHCP server container is running and has leases:

```bash
docker ps --format '{{.Names}}' | grep '^clab-enterprise-ospf-bgp-dhcp$'
```

```bash
docker exec clab-enterprise-ospf-bgp-dhcp cat /var/lib/misc/dnsmasq.leases
```

```bash
docker exec clab-enterprise-ospf-bgp-dhcp ps aux | grep dnsmasq
```

```bash
docker logs clab-enterprise-ospf-bgp-dhcp | tail -n 50
```

Check that the relay clients obtained addresses and routes:

```bash
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT ip addr show eth1
```

```bash
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT ip route
```

```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ip addr show eth1
```

```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ip route
```

If you want to validate the residential path too, confirm the gateway and downstream client:

```bash
docker exec clab-enterprise-ospf-bgp-RESIDENTIAL-BOX ip addr show eth1
```

```bash
docker exec clab-enterprise-ospf-bgp-RESIDENTIAL-BOX ip addr show eth2
```

```bash
docker exec clab-enterprise-ospf-bgp-RESIDENTIAL-BOX ip route
```

```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ping -c 3 120.0.36.10
```

## Web service

### Public website

The public site must work by IP and by DNS for everyone.

```bash
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'wget -qO- http://172.20.20.34 | grep -m1 "Page web des fans de Corentin Pradier"'
```

```bash
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'nslookup extranet.corentinpradier.com 172.20.20.30'
```

```bash
docker exec clab-enterprise-ospf-bgp-test-site sh -lc 'wget -qO- --header="Host: extranet.corentinpradier.com" http://172.20.20.34 | grep -m1 "Page web des fans de Corentin Pradier"'
```

### Intranet website

The intranet site must be reachable only from the DHCP lease ranges that belong to `enterprise` and `private` clients.

```bash
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 172.20.20.30'
```

```bash
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://172.20.20.34 | grep -m1 "Connexion Intranet"'
```

## VoIP smoke test

Once the lab is up, open the two softphones in separate terminals:

```bash
cd voip-lab
make phone-site
```

```bash
cd voip-lab
make phone-nomad
```

From `phone-site`, place the call:

```text
/dial 1002
```

In `phone-nomad`, answer it:

```text
/accept
```

To end the call:

```text
/hangup
```