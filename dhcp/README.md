# DHCP service

## Architecture overview

The lab uses a central DHCP server on the P1 service LAN and DHCP relays on edge routers.

- Central DHCP server: `clab-enterprise-ospf-bgp-dhcp`
- Central DHCP service IP: `120.0.36.3/31` on `eth1`
- Central DHCP gateway: `120.0.36.2` (router `P1`)

The direct client segment on `PE-nomad` is `120.0.38.0/24` (attached to `ethernet-1/4.0`):

- `PE-nomad` service IP: `120.0.38.1/24`
- DHCP relay target: `120.0.36.3`
- Client address pool: `120.0.38.100-120.0.38.200/24`
- DNS handed to clients: `120.0.36.1`

The central container runs `dnsmasq` with one relayed scope for the PE-nomad clients.

Relay is configured on `PE-nomad` for `120.0.38.0/24`; relayed packets are forwarded to
`120.0.36.3` with `giaddr` set so `dnsmasq` selects the correct pool.

## CRISP DHCP service (updated)

CRISP runs a small DHCP server for CRISP internal services and relayed clients.

- DHCP container: `clab-enterprise-ospf-bgp-dhcp-crisp`
- DHCP service IP: `120.0.41.10/24` on `eth1` (CRISP services VLAN)
- CRISP service gateway: `120.0.41.1` (router `CRISP`)
- Client subnet served through relay: `10.12.30.0/24`
- Lease pool: `10.12.30.100-10.12.30.200/24`
- Router handed to clients: `10.12.30.1`
- DNS handed to clients: `120.0.36.1`

The CRISP router relays DHCP from the CRISP client VLAN (`10.12.30.0/24`) to
the local server at `120.0.41.10` (see `topology.clab.yaml` for details).

Quick checks for CRISP DHCP:

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.41.10
docker exec clab-enterprise-ospf-bgp-dhcp-crisp cat /var/lib/misc/dnsmasq.leases
```

## Home CE (consumer) / Nomad CPE behaviour

The old `RESIDENTIAL-BOX` appliance was removed; the topology now models a
consumer home gateway (`home-ce`) and a preconfigured CPE (`ovpn-nomad`).

- `home-ce` WAN on `eth1`: receives an address via DHCP from the central server on `120.0.38.0/24`.
- `home-ce` LAN on `eth2`: `192.168.1.1/24` (local home network)
- `home-ce` runs NAT (MASQUERADE) for LAN -> WAN traffic.
- `ovpn-nomad` represents the user's CPE plugged into the home LAN; it uses
	`192.168.1.10/24` on its LAN side and dials the CRISP OpenVPN concentrator.

There is no longer a residential `dnsmasq` in the topology; LAN host addressing
is modelled by the `home-ce` configuration in the lab.

## Quick checks

Check active leases on the central DHCP server:

```bash
docker exec clab-enterprise-ospf-bgp-dhcp cat /var/lib/misc/dnsmasq.leases
```

If relayed clients fail to obtain leases, verify DHCP relay is configured on the
relevant edge router (e.g. `PE-nomad` or `CRISP`) and forwarding to `120.0.36.3` or
`120.0.41.10` as appropriate.

## End-to-end test procedure (short)

1. Rebuild the lab from scratch:

```bash
sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

2. Confirm expected containers exist:

```bash
docker ps --format '{{.Names}}' | grep -E 'TESTCLIENT|NOMAD-CLIENT|CRISP-CLIENT|dhcp|dhcp-crisp'
```

3. Check relay clients receive addresses and routes:

```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ip route
```

4. Validate central DHCP process and logs:

```bash
docker ps --format '{{.Names}}' | grep '^clab-enterprise-ospf-bgp-dhcp$'
docker exec clab-enterprise-ospf-bgp-dhcp ps aux | grep dnsmasq
docker logs clab-enterprise-ospf-bgp-dhcp | tail -n 50
docker exec clab-enterprise-ospf-bgp-dhcp cat /var/lib/misc/dnsmasq.leases
```

5. For home/nomad path checks (home CE + CPE):

```bash
docker exec clab-enterprise-ospf-bgp-home-ce ip addr show eth1
docker exec clab-enterprise-ospf-bgp-home-ce ip addr show eth2
docker exec clab-enterprise-ospf-bgp-home-ce ip route
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ping -c 3 120.0.36.3
```

6. Validate DNS reachability from the direct PE-nomad client:

```bash
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT nslookup intranet.corentinpradier.com 120.0.36.1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT nslookup voip.corentinpradier.com 120.0.36.1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ping -c 3 120.0.36.1
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT ping -c 3 120.0.36.3
```

## Lease inspection (example)

Check whether a particular client lease exists on the central or CRISP DHCP servers:

```bash
docker exec clab-enterprise-ospf-bgp-dhcp grep 192.168.1.168 /var/lib/misc/dnsmasq.leases || true
docker exec clab-enterprise-ospf-bgp-dhcp-crisp grep 10.12.30.101 /var/lib/misc/dnsmasq.leases || true
```

## Packet capture (optional)

If `tcpdump` is available in the container image:

```bash
docker exec -it clab-enterprise-ospf-bgp-dhcp tcpdump -ni eth1 -s 0 -vv udp port 67 or udp port 68
```

This helps confirm DHCPDISCOVER/OFFER/REQUEST/ACK and whether relayed requests carry `giaddr`.

## Testing from a physical device (`dhclient`)

Use a Linux laptop or host attached to the appropriate host bridge (for example
`net-home` for a nomad/home path or `net-nomad` for a direct PE-nomad client).
Then run `dhclient` on the wired interface to request a lease from the lab DHCP
infrastructure.

Example (replace `<iface>` with your interface name, e.g. `eth0` or `enp3s0`):

```bash
# Bring the interface up and clear any previous leases
sudo ip link set <iface> down
sudo dhclient -r <iface> || true
sudo ip link set <iface> up

# Request a new lease (verbose)
sudo dhclient -v <iface>

# Inspect assigned address and routes
ip addr show <iface>
ip route show
ping -c 3 120.0.36.1   # DNS server
ping -c 3 120.0.36.3   # central DHCP server
```

Notes:
- If you're testing the home/nomad path (CPE -> home CE -> PE-nomad), attach the
	device to `net-home` (host bridge) so the `home-ce` and `ovpn-nomad` paths are
	exercised.
- For CRISP client testing, attach to the CRISP client bridge (`net-crisp-cli`).
- To force a fresh DHCP request, use `sudo dhclient -r <iface>` before requesting
	a new lease.
- If you need to inspect DHCP packets live, run `tcpdump` on the relevant lab
	container/interface (see Packet capture above).
