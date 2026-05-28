# DNS service

## Architecture overview

Two BIND9 nameservers:

| Node | Role | Service IP | Mgmt IP | Container name |
| --- | --- | --- | --- | --- |
| `dns-as12` | AS12 authoritative resolver (views) | `120.0.36.1/31` | `clab-enterprise-ospf-bgp-dns-as12` |
| `dns-root` | Lab root nameserver (sync point for inter-AS DNS) | `120.0.36.5/31` | `clab-enterprise-ospf-bgp-dns-root` |

`dns-as12` config is split by views in `dns/views.conf` (loaded by `dns/named.conf`).
`dns-root` is a separate, single-purpose authoritative server for `.` configured under `dns/root/`.

### Lab root DNS — the inter-AS sync point

Each AS keeps its own authoritative zone (we keep `corentinpradier.com`). To resolve a peer AS's zone without depending on that peer's resolver being up — and to avoid bring-up order coupling — every AS resolver iterates from a shared root: `dns-root` (`120.0.36.5/31`). The root only holds NS delegations + glue, one entry per AS.

```
clients --> dns-as12 (recursive, views) --> dns-root (.)
                                              |- corentinpradier.com.  --> 120.0.36.1  (AS12)
                                              |- <as11-zone>.          --> <as11-ip>   (TODO)
                                              |- <as13-zone>.          --> 120.0.48.34 (TODO)
                                              |- <as14-zone>.          --> <as14-ip>   (TODO)
```

Reachability today: `dns-root` sits on the dedicated `120.0.36.4/31` link off `P2`, advertised as a passive OSPF interface so every internal node can reach it.

Adding a peer AS: (one block in `dns/root/db.root`):

```bind
<peer-zone>.    IN NS    ns.<peer-zone>.
ns.<peer-zone>. IN A     <peer-dns-ip>
```

### AS12 resolver (`dns-as12`) layout

- `dns/named.conf` — loads options + views.
- `dns/named.conf.options` — ACLs (crisp-employees / crisp-nets / residential-nets), no global forwarders (we iterate via root hints).
- `dns/root.hints` — root hint pointing at `dns-root` (`120.0.36.5`).
- `dns/views.conf` — three views (enterprise / residential / default); the two recursive views include a `zone "."` of type `hint`.
- `dns/zones/db.corentinpradier.com{,.public}` — the AS12 authoritative zone (internal + public variant).

### Verify the root chain

```bash
# 1. dns-root is reachable + authoritative for `.`
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 . SOA +norec
#    → answer with AA flag, SOA root-srv.lab. admin.lab. ...

# 2. dns-root delegates our zone (NS + glue)
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 corentinpradier.com NS +norec
#    → AUTHORITY: corentinpradier.com. NS ns.corentinpradier.com.
#    → ADDITIONAL: ns.corentinpradier.com. A 120.0.36.1

# 3. dns-as12 can still resolve the root and its glue
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 root-srv.lab A +norec
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 ns.n7. A +norec

# 4. End-to-end iterative path for the delegated peer AS we already publish:
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'dig @120.0.36.1 n7. NS +norec'
#    → resolves via dns-as12 -> dns-root -> delegation + glue
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 . SOA +norec

; <<>> DiG 9.21.21 <<>> @120.0.36.5 . SOA +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 16726
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: d74bb028c3cc52e6010000006a18b84603f0b128e0884c4b (good)
;; QUESTION SECTION:
;.                              IN      SOA

;; ANSWER SECTION:
.                       86400   IN      SOA     root-srv.lab. admin.lab. 2026052800 7200 1800 604800 86400

;; Query time: 2 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Thu May 28 21:48:54 UTC 2026
;; MSG SIZE  rcvd: 109

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 corentinpradier.com NS +norec

; <<>> DiG 9.21.21 <<>> @120.0.36.5 corentinpradier.com NS +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 14780
;; flags: qr; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: decf69756df6d503010000006a18b84993669daf30f9f906 (good)
;; QUESTION SECTION:
;corentinpradier.com.           IN      NS

;; AUTHORITY SECTION:
corentinpradier.com.    86400   IN      NS      ns.corentinpradier.com.

;; ADDITIONAL SECTION:
ns.corentinpradier.com. 86400   IN      A       120.0.36.1

;; Query time: 2 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Thu May 28 21:48:57 UTC 2026
;; MSG SIZE  rcvd: 109

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 root-srv.lab A +norec
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 ns.n7. A +norec

; <<>> DiG 9.21.21 <<>> @120.0.36.5 root-srv.lab A +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 44998
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: cbd14b53d5cdb248010000006a18b84e8f2c4ac6d87a3923 (good)
;; QUESTION SECTION:
;root-srv.lab.                  IN      A

;; ANSWER SECTION:
root-srv.lab.           86400   IN      A       120.0.34.14

;; Query time: 2 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Thu May 28 21:49:02 UTC 2026
;; MSG SIZE  rcvd: 85


; <<>> DiG 9.21.21 <<>> @120.0.36.5 ns.n7. A +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 59882
;; flags: qr; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: cd47afb9fda6539c010000006a18b84eb9d9fa31b687bb45 (good)
;; QUESTION SECTION:
;ns.n7.                         IN      A

;; AUTHORITY SECTION:
n7.                     86400   IN      NS      ns.n7.

;; ADDITIONAL SECTION:
ns.n7.                  86400   IN      A       120.0.30.1

;; Query time: 2 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Thu May 28 21:49:02 UTC 2026
;; MSG SIZE  rcvd: 92

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'dig @120.0.36.1 n7. NS +norec'

; <<>> DiG 9.20.23 <<>> @120.0.36.1 n7. NS +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 55988
;; flags: qr ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: a5d9ecfe6a8b9dd4010000006a18b852d12bbc396e437b50 (good)
;; QUESTION SECTION:
;n7.                            IN      NS

;; AUTHORITY SECTION:
.                       86400   IN      NS      root-srv.lab.

;; Query time: 4 msec
;; SERVER: 120.0.36.1#53(120.0.36.1) (UDP)
;; WHEN: Thu May 28 21:49:06 UTC 2026
;; MSG SIZE  rcvd: 84

t70n@t70n-workstation:~/Documents/crisp$ 
```

The iterative chain only has anything to iterate to once at least one peer AS publishes its delegation in `dns/root/db.root`; `n7.` is the current example. The AS12 zone is answered locally by the matching view and never hits the root.

## Views and ACL behavior

View selection depends on source IP (client subnet):

- CRISP employees ACL: `10.12.30.0/24` and VPN users
- Residential ACL: `120.0.38.0/24`
- Default view: all other addresses

View selection is source-IP based, so answers can change depending on the client address.
This allows us to control whether a client can resolve the intranet website or not. VoIP and extranet are always available, while intranet resolution is limited to CRISP employees and the nomad VPN CPE (`192.168.1.10`).

Our services are under the domain `corentinpradier.com`:

- `extranet.corentinpradier.com` -> `120.0.40.3` (public + enterprise/CRISP)
- `intranet.corentinpradier.com` -> `120.0.40.3` (enterprise/CRISP only) (the website content differs between extranet and intranet)
- `voip.corentinpradier.com` -> `120.0.41.5`

## Quick host checks

Quick test from the DNS server management IP (this is why docker is usefull : direct access to emulated network):

```bash
dig @172.20.20.30 extranet.corentinpradier.com
dig @172.20.20.30 voip.corentinpradier.com
dig @172.20.20.30 intranet.corentinpradier.com
```

Expected results:

Note that the NXDOMAIN result is expected for intranet dig because the command is hitting the DNS server from a source that lands in the default view. `intranet.corentinpradier.com` is not in that view, so NXDOMAIN is expected.

```bash
t70n@t70n-workstation:~/Documents/crisp$ dig @172.20.20.30 extranet.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 extranet.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 41183
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 714bba466568a079010000006a18b8f7475a45d34f736a1b (good)
;; QUESTION SECTION:
;extranet.corentinpradier.com.  IN      A

;; ANSWER SECTION:
extranet.corentinpradier.com. 3600 IN   A       120.0.40.3

;; Query time: 1 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Thu May 28 23:51:51 CEST 2026
;; MSG SIZE  rcvd: 101

t70n@t70n-workstation:~/Documents/crisp$ dig @172.20.20.30 voip.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 voip.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 24000
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: b1aeafb839349f68010000006a18b8fb58f81daea3987a1b (good)
;; QUESTION SECTION:
;voip.corentinpradier.com.      IN      A

;; ANSWER SECTION:
voip.corentinpradier.com. 3600  IN      A       120.0.41.5

;; Query time: 1 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Thu May 28 23:51:55 CEST 2026
;; MSG SIZE  rcvd: 97

t70n@t70n-workstation:~/Documents/crisp$ dig @172.20.20.30 intranet.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 intranet.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 24958
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 3bea72793ab5ee20010000006a18b8fee8ee29b033bf27b3 (good)
;; QUESTION SECTION:
;intranet.corentinpradier.com.  IN      A

;; AUTHORITY SECTION:
corentinpradier.com.    3600    IN      SOA     ns.corentinpradier.com. admin.corentinpradier.com. 2026052202 7200 1800 604800 3600

;; Query time: 1 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Thu May 28 23:51:58 CEST 2026
;; MSG SIZE  rcvd: 130

t70n@t70n-workstation:~/Documents/crisp$ 
```

## Client side checks

Use the CRISP employee client and the VPN CPE to verify the protected intranet view, then confirm a non-CRISP client still gets NXDOMAIN.
We do not specify address of DNS as it should be given by DHCP configuration.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1 || true'
docker exec clab-enterprise-ospf-bgp-ovpn-nomad sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1 || true'
Server:         120.0.36.1
Address:        120.0.36.1:53

** server can't find intranet.corentinpradier.com: NXDOMAIN

** server can't find intranet.corentinpradier.com: NXDOMAIN

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-ovpn-nomad sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
;; connection timed out; no servers could be reached
```