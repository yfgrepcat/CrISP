# DHCP service

This is the main DHCP server on the P1 side. Clients ask through the relay on PE-nomad, and the server gives back the lease, gateway, and DNS for that network.

## Architecture overview

The lab uses a central DHCP server on the P1 service LAN and a DHCP relay on the nomad edge.
- DHCP server: `dhcp`
- DHCP service IP: `120.0.36.3/31`
- DHCP gateway: `120.0.36.2` (router `P1`)

The direct client segment on PE-nomad is `120.0.38.0/24`, addressed by our AS DHCP.
- `PE-nomad` service IP (gateway): `120.0.38.1/24`
- DHCP relay target: `120.0.36.3`
- Client address pool: `120.0.38.100-120.0.38.200/24`
- DNS handed to clients (AS12 dns, not root): `120.0.36.1`

Quick configuration check (leave the lab running for a few minutes to give clients time to get IPs):

```bash
docker exec clab-enterprise-ospf-bgp-dhcp cat /var/lib/misc/dnsmasq.leases
```

## How DHCP DNS option works

The DHCP servers already advertise `option:dns-server,120.0.36.1`, but that alone is not enough on Alpine image based clients.
--> Docker keeps its own generated `/etc/resolv.conf` unless the DHCP client updates it.

To make the DNS server come from DHCP instead of a hard-coded docker configuration, the DHCP clients now run `udhcpc` with the script in `scripts/udhcpc-resolvconf.sh`.
The script is mounted into DHCP containers from [scripts/udhcpc-resolvconf.sh](../../scripts/udhcpc-resolvconf.sh).

That hook does two things when a lease is received:
- configures the leased IPv4 address on `eth1`
- writes the DHCP-provided `dns` list into `/etc/resolv.conf`

This is what makes `nslookup intranet.corentinpradier.com` work without passing `120.0.36.1` explicitly.

This is the only solution we found that works, avoiding hard-coding the configuration in Docker.

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
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT cat /etc/resolv.conf
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com
nameserver 120.0.36.1
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ 
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT cat /etc/resolv.conf
nameserver 120.0.36.1
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup intranet.corentinpradier.com
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT cat /etc/resolv.conf
nameserver 120.0.36.1
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT nslookup voip.corentinpradier.com
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   voip.corentinpradier.com
Address: 120.0.41.5


t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-home-ce cat /etc/resolv.conf
nameserver 120.0.36.1
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-home-ce nslookup extranet.corentinpradier.com
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   extranet.corentinpradier.com
Address: 120.0.40.3
```

We can see that every client is getting an IP address, so it works.

## Home CE behavior

`home-ce` is the residential edge router in the topology:
- WAN on `eth1`: gets an address in `120.0.38.0/24` via central DHCP
- LAN on `eth2`: `192.168.1.1/24`
- NAT enabled from LAN to WAN (`MASQUERADE` on `eth1`)

It uses the shared DHCP script so the WAN-side resolver also comes from the DHCP lease. 
