# DHCP service

## Architecture overview

The lab uses a central DHCP server on the P1 service LAN and a DHCP relay on the nomad edge.

- Central DHCP server: `dhcp`
- Central DHCP service IP: `120.0.36.3/31`
- Central DHCP gateway: `120.0.36.2` (router `P1`)

The direct client segment on PE-nomad is `120.0.38.0/24` behind `ethernet-1/4.0`, addressed by our AS DHCP.

- `PE-nomad` service IP: `120.0.38.1/24`
- DHCP relay target: `120.0.36.3`
- Client address pool: `120.0.38.100-120.0.38.200/24`
- DNS handed to clients: `120.0.36.1`

The central container runs `dnsmasq` with 1 scope:

- Relayed private pool: `120.0.38.100-120.0.38.200/24`

Relay is configured on:

- `PE-nomad` for `120.0.38.0/24` 

It relays to `120.0.36.3` and sets `giaddr` so `dnsmasq` picks the right pool.

Quick check : 

```bash
docker exec clab-enterprise-ospf-bgp-dhcp cat /var/lib/misc/dnsmasq.leases
```

## How DHCP DNS option works

The DHCP servers already advertise `option:dns-server,120.0.36.1`, but that alone is not enough on Alpine image based clients because Docker keeps its own generated `/etc/resolv.conf` unless the DHCP client updates it.

To make the DNS server come from DHCP instead of a hard-coded docker configuration, the DHCP clients now run `udhcpc` with the repository hook in `scripts/udhcpc-resolvconf.sh`.

That hook does two things when a lease is received:

- configures the leased IPv4 address on `eth1`
- writes the DHCP-provided `dns` list into `/etc/resolv.conf`

This is what makes `nslookup intranet.corentinpradier.com` work without passing `120.0.36.1` explicitly.

This is only solution we achieved to make work, avoiding us to hard-code the configuration in the docker.

The script is mounted into DHCP containers from [scripts/udhcpc-resolvconf.sh](../scripts/udhcpc-resolvconf.sh).

## Verify DHCP option DNS

Use these commands to confirm that DNS is coming from the DHCP lease:

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT cat /etc/resolv.conf
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com

docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT cat /etc/resolv.conf
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT nslookup voip.corentinpradier.com

docker exec clab-enterprise-ospf-bgp-home-ce cat /etc/resolv.conf
docker exec clab-enterprise-ospf-bgp-home-ce nslookup extranet.corentinpradier.com
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT cat /etc/resolv.conf
nameserver 120.0.36.1

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT nslookup voip.corentinpradier.com
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   voip.corentinpradier.com
Address: 120.0.41.5
```

## CRISP DHCP service

CRISP also has a small DHCP server in the DMZ for the private client net.

- DHCP container: `dhcp-crisp`
- DHCP IP: `120.0.40.10/24`
- DMZ gateway: 
- Client subnet served through relay: `10.12.30.0/24`
- Lease pool: `10.12.30.100-10.12.30.200/24`
- Router handed to clients: `10.12.30.1`
- DNS handed to clients: `120.0.36.1`

The CRISP router relays DHCP on `e1-3` from the private client net to the DMZ server at `120.0.40.10`.

Test: 

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.41.10
docker exec clab-enterprise-ospf-bgp-dhcp-crisp cat /var/lib/misc/dnsmasq.leases
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

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.41.10
PING 120.0.41.10 (120.0.41.10): 56 data bytes
64 bytes from 120.0.41.10: seq=0 ttl=63 time=0.780 ms
64 bytes from 120.0.41.10: seq=1 ttl=63 time=0.771 ms
64 bytes from 120.0.41.10: seq=2 ttl=63 time=0.343 ms

--- 120.0.41.10 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.343/0.631/0.780 ms

70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dhcp-crisp cat /var/lib/misc/dnsmasq.leases
1780045745 aa:c1:ab:bf:ac:f3 10.12.30.156 * 01:aa:c1:ab:bf:ac:f3
```

## Home CE behavior

`home-ce` is the residential edge router in the topology:

- WAN on `eth1`: gets an address in `120.0.38.0/24` via central DHCP
- LAN on `eth2`: `192.168.1.1/24`
- NAT enabled from LAN to WAN (`MASQUERADE` on `eth1`)

It uses the shared DHCP script so the WAN-side resolver also comes from the DHCP lease. The DHCP `router` option is still the primary source of the default gateway, but `home-ce` also installs a safety route to `120.0.38.1` so the CE keeps working even if the lease hook races the link bring-up during deploy.
