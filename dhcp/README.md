# DHCP service

## Architecture overview

The lab uses a central DHCP server on the P1 service LAN and a DHCP relay on the nomad edge.

- Central DHCP server: `clab-enterprise-ospf-bgp-dhcp`
- Central DHCP service IP: `120.0.36.3/31` on `eth1`
- Central DHCP gateway: `120.0.36.2` (router `P1`)

The direct client segment on PE-nomad is `120.0.38.0/24` behind `ethernet-1/4.0`:

- `PE-nomad` service IP: `120.0.38.1/24`
- DHCP relay target: `120.0.36.3`
- Client address pool: `120.0.38.100-120.0.38.200/24`
- DNS handed to clients: `120.0.36.1`

The central container runs `dnsmasq` with 1 scope:

- Relayed private pool: `120.0.38.100-120.0.38.200/24`

Relay is configured on:

- `PE-nomad` for `120.0.38.0/24` (`ethernet-1/4.0`)

It relays to `120.0.36.3` and sets `giaddr` so `dnsmasq` picks the right pool.

## CRISP DHCP service

CRISP also has a small DHCP server in the DMZ for the private client net.

- DHCP container: `clab-enterprise-ospf-bgp-dhcp-crisp`
- DHCP service IP: `120.0.40.10/24` on `eth1`
- DMZ gateway: `120.0.40.1` (router `CRISP`)
- Client subnet served through relay: `10.12.30.0/24`
- Lease pool: `10.12.30.100-10.12.30.200/24`
- Router handed to clients: `10.12.30.1`
- DNS handed to clients: `120.0.36.1`

The CRISP router relays DHCP on `e1-3` from the private client net to the DMZ server at `120.0.40.10`.

Quick checks:

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.40.10
docker exec clab-enterprise-ospf-bgp-dhcp-crisp cat /var/lib/misc/dnsmasq.leases
```

## Residential box behavior

`RESIDENTIAL-BOX` is a small consumer-gateway simulation:

- WAN on `eth1`: gets an address in `120.0.38.0/24` via central DHCP
- LAN on `eth2`: `192.168.1.1/24`
- Local DHCP/DNS on LAN via `dnsmasq` (`192.168.1.100-192.168.1.200`)
- NAT enabled from LAN to WAN (`MASQUERADE` on `eth1`)

The box bootstrap script is in `dhcp/residential/setup-box.sh`.

## Quick checks

Check active leases on the central server:

```bash
docker exec clab-enterprise-ospf-bgp-dhcp cat /var/lib/misc/dnsmasq.leases
```

If relayed clients fail to obtain leases, verify DHCP relay is configured on the routers and forwarding to `120.0.36.3`.

## End-to-end test procedure

1. Rebuild the lab from scratch.

```bash
sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

2. Confirm the expected containers exist and `TESTCLIENT` is not present.

```bash
docker ps --format '{{.Names}}' | grep -E 'TESTCLIENT|SITE-CLIENT|NOMAD-CLIENT|RESIDENTIAL-BOX|dhcp'
```

Expected result: `SITE-CLIENT`, `NOMAD-CLIENT`, `RESIDENTIAL-BOX`, and `dhcp` appear; `TESTCLIENT` does not.

3. Check relay clients receive addresses and routes.

```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-SITE-CLIENT ip route
```

4. Validate central DHCP process and logs.

```bash
docker ps --format '{{.Names}}' | grep '^clab-enterprise-ospf-bgp-dhcp$'
docker exec clab-enterprise-ospf-bgp-dhcp ps aux | grep dnsmasq
docker logs clab-enterprise-ospf-bgp-dhcp | tail -n 50
docker exec clab-enterprise-ospf-bgp-dhcp cat /var/lib/misc/dnsmasq.leases
```

5. If residential path is in scope, validate residential gateway bootstrap and downstream behavior.

```bash
docker exec clab-enterprise-ospf-bgp-RESIDENTIAL-BOX ip addr show eth1
docker exec clab-enterprise-ospf-bgp-RESIDENTIAL-BOX ip addr show eth2
docker exec clab-enterprise-ospf-bgp-RESIDENTIAL-BOX ip route
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ping -c 3 120.0.36.3
```

6. Validate DNS reachability from the direct PE-nomad client.

```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT nslookup intranet.corentinpradier.com 120.0.36.1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT nslookup voip.corentinpradier.com 120.0.36.1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ping -c 3 120.0.36.1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ping -c 3 120.0.36.3
```

## Residential lease inspection

Check whether a LAN client lease exists on central and residential DHCP servers:

```bash
docker exec clab-enterprise-ospf-bgp-dhcp grep 192.168.1.168 /var/lib/misc/dnsmasq.leases || true
docker exec clab-enterprise-ospf-bgp-RESIDENTIAL-BOX grep 192.168.1.168 /var/lib/misc/dnsmasq.leases || true
```

## Packet capture (optional)

If `tcpdump` is available in the container image:

```bash
docker exec -it clab-enterprise-ospf-bgp-dhcp tcpdump -ni eth1 -s 0 -vv udp port 67 or udp port 68
```

This helps confirm DHCPDISCOVER/OFFER/REQUEST/ACK and whether relayed requests carry `giaddr`.