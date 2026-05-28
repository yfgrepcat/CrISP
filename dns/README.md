# DNS service

## Architecture overview

Two BIND9 nameservers:

| Node | Role | Service IP | Mgmt IP | Container name |
| --- | --- | --- | --- | --- |
| `dns-as12` | AS12 authoritative resolver (views) | `120.0.36.1/31` (P1 service LAN) | `172.20.20.30` | `clab-enterprise-ospf-bgp-dns-as12` |
| `dns-root` | Lab root nameserver (sync point for inter-AS DNS) | `120.0.34.14/30` (off PE-isp:e1-5) | `172.20.20.40` | `clab-enterprise-ospf-bgp-dns-root` |

`dns-as12` config is split by views in `dns/views.conf` (loaded by `dns/named.conf`).
`dns-root` is a separate, single-purpose authoritative server for `.` configured under `dns/root/`.

### Lab root DNS — the inter-AS sync point

Each AS keeps its own authoritative zone (we keep `corentinpradier.com`). To resolve a peer AS's zone without depending on that peer's resolver being up — and to avoid bring-up order coupling — every AS resolver iterates from a shared root: `dns-root` (`120.0.34.14`). The root only holds NS delegations + glue, one entry per AS.

```
clients ──► dns-as12 (recursive, views) ──► dns-root (.)
                                              ├─ corentinpradier.com.  → 120.0.36.1  (AS12)
                                              ├─ <as11-zone>.          → <as11-ip>   (TODO)
                                              ├─ <as13-zone>.          → 120.0.48.34 (TODO add zone name)
                                              └─ <as14-zone>.          → <as14-ip>   (TODO)
```

Reachability today: `dns-root` sits on the dedicated `120.0.34.12/30` link off `PE-isp` (e1-5 .13 ↔ dns-root .14), advertised as a passive OSPF interface so every internal node can reach it. To let peer ASes use it, the same prefix should be re-advertised over eBGP from `PE-isp` once inter-AS peering is wired.

**Why this beats a forwarder list**: with `forwarders { peerA; peerB; … }; forward first;`, a peer's `NXDOMAIN` is authoritative and aborts the lookup, and any peer being down adds latency to every uncached query. With root hints + delegation, the answer for `peer-zone.X` is fetched directly from peer X's own NS — no other AS sits in the critical path.

**Adding a peer AS** (one block in `dns/root/db.root`):

```bind
<peer-zone>.    IN NS    ns.<peer-zone>.
ns.<peer-zone>. IN A     <peer-dns-ip>
```

Then bump the SOA serial in `dns/root/db.root` and reload `dns-root`.

### AS12 resolver (`dns-as12`) layout

- `dns/named.conf` — loads options + views.
- `dns/named.conf.options` — ACLs (crisp-employees / crisp-nets / residential-nets), no global forwarders (we iterate via root hints).
- `dns/root.hints` — root hint pointing at `dns-root` (`120.0.34.14`).
- `dns/views.conf` — three views (enterprise / residential / default); the two recursive views include a `zone "."` of type `hint`.
- `dns/zones/db.corentinpradier.com{,.public}` — the AS12 authoritative zone (internal + public variant).

### Verify the root chain

```bash
# 1. dns-root is reachable + authoritative for `.`
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.34.14 . SOA +norec
#    → answer with AA flag, SOA root-srv.lab. admin.lab. ...

# 2. dns-root delegates our zone (NS + glue)
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.34.14 corentinpradier.com NS +norec
#    → AUTHORITY: corentinpradier.com. NS ns.corentinpradier.com.
#    → ADDITIONAL: ns.corentinpradier.com. A 120.0.36.1

# 3. dns-as12 has the root hint loaded
docker exec clab-enterprise-ospf-bgp-dns-as12 rndc dumpdb -cache && \
  docker exec clab-enterprise-ospf-bgp-dns-as12 grep -m1 root-srv.lab /var/cache/bind/named_dump.db || true

# 4. (Once a peer AS has been added to db.root) iterative path end-to-end:
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc '
  nslookup <name-in-peer-zone> 120.0.36.1
'
#    → resolves via root → peer NS → answer
```

The iterative chain only has anything to iterate to once at least one peer AS publishes its delegation in `dns/root/db.root`; until then the AS12 zone is answered locally by the matching view and never hits the root.

## Views and ACL behavior

View selection depends on source IP (client subnet):

- CRISP employees ACL: `10.12.30.0/24` and VPN user `192.168.1.10/32`
- Residential ACL: `120.0.38.0/24`
- Default view: all other addresses

View selection is source-IP based, so answers can change depending on the client address.
This allows us to control whether a client can resolve the intranet website or not. VoIP and extranet are always available, while intranet resolution is limited to CRISP employees and the nomad VPN CPE (`192.168.1.10`).

Our services are under the domain `corentinpradier.com`:

- `extranet.corentinpradier.com` -> `120.0.40.3` (public + enterprise/CRISP)
- `intranet.corentinpradier.com` -> `120.0.40.3` (enterprise/CRISP only) (the website content differs between extranet and intranet)
- `voip.corentinpradier.com` -> `120.0.40.5`

## Quick rebuild

From repo root:

```bash
sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## Quick host checks

Quick test from the DNS server management IP:

```bash
dig @172.20.20.30 extranet.corentinpradier.com
dig @172.20.20.30 voip.corentinpradier.com
dig @172.20.20.30 intranet.corentinpradier.com
```

Expected results:

```bash
t70n@t70n-workstation:~/Documents/enterprise-network$ dig @172.20.20.30 extranet.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 extranet.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 51778
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: e6430cb7553421c7010000006a16ee6ecbc1f69d5d447b4e (good)
;; QUESTION SECTION:
;extranet.corentinpradier.com.  IN      A

;; ANSWER SECTION:
extranet.corentinpradier.com. 3600 IN   A       172.20.20.34

;; Query time: 0 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Wed May 27 15:15:26 CEST 2026
;; MSG SIZE  rcvd: 101
```

```bash
t70n@t70n-workstation:~/Documents/enterprise-network$ dig @172.20.20.30 voip.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 voip.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 57584
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: e8cfdabdf6fc59af010000006a16ee7e09ebe418970d625a (good)
;; QUESTION SECTION:
;voip.corentinpradier.com.      IN      A

;; ANSWER SECTION:
voip.corentinpradier.com. 3600  IN      A       120.0.35.1

;; Query time: 1 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Wed May 27 15:15:42 CEST 2026
;; MSG SIZE  rcvd: 97
```

The NXDOMAIN result is expected because the command is hitting the DNS server from a source that lands in the default view.
`intranet.corentinpradier.com` is not in that view, so NXDOMAIN is expected.

```bash
t70n@t70n-workstation:~/Documents/enterprise-network$ dig @172.20.20.30 intranet.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 intranet.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 20231
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 580554c5cc2d4a2c010000006a16ee8f40f09e0aafb434cc (good)
;; QUESTION SECTION:
;intranet.corentinpradier.com.  IN      A

;; AUTHORITY SECTION:
corentinpradier.com.    3600    IN      SOA     ns.corentinpradier.com. admin.corentinpradier.com. 2026052202 7200 1800 604800 3600

;; Query time: 0 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Wed May 27 15:15:59 CEST 2026
;; MSG SIZE  rcvd: 130
```

## View test (CRISP employees vs VPN vs residential)

Run from the DNS container by creating temporary dummy source IPs inside the real ACL subnets.

```bash
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add ent0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 10.12.30.10/24 dev ent0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set ent0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add vpn0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 192.168.1.10/32 dev vpn0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set vpn0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add res0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 120.0.38.10/24 dev res0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set res0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 10.12.30.10 @120.0.36.1 intranet.corentinpradier.com
docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 192.168.1.10 @120.0.36.1 intranet.corentinpradier.com
docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 120.0.38.10 @120.0.36.1 intranet.corentinpradier.com
```

Expected: DNS resolution for intranet works when the source address is in the CRISP employee or VPN ranges, which match the ACLs in `named.conf.options`:
- acl "crisp-employees" { 10.12.30.0/24; vpn-users; };
- acl "vpn-users" { 192.168.1.10/32; 10.255.255.0/30; };
- acl "residential-nets" { 120.0.38.0/24; };

```bash
t70n@t70n-workstation:~/Documents/enterprise-network$ docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add ent0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 10.12.30.10/24 dev ent0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set ent0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add vpn0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 192.168.1.10/32 dev vpn0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set vpn0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 ip link add res0 type dummy
docker exec clab-enterprise-ospf-bgp-dns-as12 ip addr add 120.0.38.10/24 dev res0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link set res0 up

docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 10.12.30.10 @120.0.36.1 intranet.corentinpradier.com
docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 192.168.1.10 @120.0.36.1 intranet.corentinpradier.com
docker exec clab-enterprise-ospf-bgp-dns-as12 dig -b 120.0.38.10 @120.0.36.1 intranet.corentinpradier.com

; <<>> DiG 9.21.21 <<>> -b 10.12.30.10 @120.0.36.1 intranet.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 60964
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 3e845558709266e7010000006a16ef08faf194dc80dcfe5c (good)
;; QUESTION SECTION:
;intranet.corentinpradier.com.  IN      A

;; ANSWER SECTION:
intranet.corentinpradier.com. 3600 IN   A       172.20.20.34

;; Query time: 1 msec
;; SERVER: 120.0.36.1#53(120.0.36.1) (UDP)
;; WHEN: Wed May 27 13:18:00 UTC 2026
;; MSG SIZE  rcvd: 101


; <<>> DiG 9.21.21 <<>> -b 192.168.1.10 @120.0.36.1 intranet.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 21973
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 1a66d913641c325f010000006a16ef08f37731e6fab8023a (good)
;; QUESTION SECTION:
;intranet.corentinpradier.com.  IN      A

;; ANSWER SECTION:
intranet.corentinpradier.com. 3600 IN   A       172.20.20.34

;; Query time: 1 msec
;; SERVER: 120.0.36.1#53(120.0.36.1) (UDP)
;; WHEN: Wed May 27 13:18:00 UTC 2026
;; MSG SIZE  rcvd: 101
```

Cleanup:

```bash
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link del ent0
docker exec clab-enterprise-ospf-bgp-dns-as12 ip link del res0
```

## Realistic client-side checks

Use the CRISP employee client and the VPN CPE to verify the protected intranet view, then confirm a non-CRISP client still gets NXDOMAIN.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-ovpn-nomad sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1 || true'
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/enterprise-network$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   intranet.corentinpradier.com
Address: 172.20.20.34


t70n@t70n-workstation:~/Documents/enterprise-network$ docker exec clab-enterprise-ospf-bgp-ovpn-nomad sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   intranet.corentinpradier.com
Address: 172.20.20.34


t70n@t70n-workstation:~/Documents/enterprise-network$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1 || true'
;; communications error to 120.0.36.1#53: timed out
;; communications error to 120.0.36.1#53: timed out
;; communications error to 120.0.36.1#53: timed out
```

Then confirm the CRISP client can still reach the DMZ:

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip addr show eth1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ip route
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.40.10
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT ping -c 3 120.0.36.1
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT nslookup voip.corentinpradier.com 120.0.36.1
```




# CRISP addressing and tests

## Exact IP plan

### PE-site to CRISP transit

- `PE-site:e1-4 = 120.0.39.0/31`
- `CRISP:e1-1 = 120.0.39.1/31`

### CRISP DMZ VLAN

- `CRISP:e1-2 = 120.0.40.1/24`
- `ovpn-site = 120.0.40.2/24`
- `reverse-proxy = 120.0.40.3/24`
- `web-server = 120.0.40.4/24`

### CRISP private services VLAN

- `CRISP:e1-3 = 120.0.41.1/24`
- `pbx = 120.0.41.5/24`
- `dhcp-crisp = 120.0.41.10/24`

### CRISP private client network

- `CRISP:e1-4 = 10.12.30.1/24`
- `CRISP-CLIENT = DHCP from 10.12.30.100-10.12.30.200`
- `phone-crisp1 = 10.12.30.101/24`
- `phone-crisp2 = 10.12.30.102/24`

## Services

- Web server service IP: `120.0.40.4`
- VoIP PBX service IP: `120.0.41.5`
- DHCP server service IP: `120.0.41.10`
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
