# DNS service

This is the AS12 DNS side. It answers our zone directly, then uses the lab root when it needs to walk to another AS.

DNS starts on this resolver for `corentinpradier.com`, and if the name is outside our zone it follows the root hints to keep iterating.

## AS12 resolver (`dns-as12`) layout

- `as12-dns/named.conf` - loads options + views.
- `as12-dns/named.conf.options` - ACLs (crisp-employees / crisp-nets / residential-nets), no global forwarders (we iterate via root hints).
- `as12-dns/root.hints` - root hint pointing at `dns-root` (`120.0.36.5`).
- `as12-dns/views.conf` - three views (enterprise / residential / default); the two recursive views include a `zone "."` of type `hint`.
- `as12-dns/zones/db.corentinpradier.com{,.public}` - the AS12 authoritative zone (internal + public variant).

## Views and ACL behavior

View selection depends on source IP (client subnet):
- CRISP employees ACL: `10.12.30.0/24` and VPN users
- Residential ACL: `120.0.38.0/24`
- Default view: all other addresses

View selection is source-IP based, so answers can change depending on the client address.

This allows us to control whether a client can resolve the intranet website or not. 
VoIP and extranet are always available, while intranet resolution is limited to CRISP employees and the nomad VPN CPE (`192.168.1.10`).

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
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49183
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 7816813984abe877010000006a1b3cbdf92fc6ca7c397805 (good)
;; QUESTION SECTION:
;extranet.corentinpradier.com.  IN      A

;; ANSWER SECTION:
extranet.corentinpradier.com. 3600 IN   A       120.0.40.3

;; Query time: 4 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Sat May 30 21:38:37 CEST 2026
;; MSG SIZE  rcvd: 101

t70n@t70n-workstation:~/Documents/crisp$ dig @172.20.20.30 voip.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 voip.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 29845
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 08b5e8cf7e91b6b6010000006a1b3cc2f0aaef12ceaf2d37 (good)
;; QUESTION SECTION:
;voip.corentinpradier.com.      IN      A

;; ANSWER SECTION:
voip.corentinpradier.com. 3600  IN      A       120.0.41.5

;; Query time: 3 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Sat May 30 21:38:42 CEST 2026
;; MSG SIZE  rcvd: 97

t70n@t70n-workstation:~/Documents/crisp$ dig @172.20.20.30 intranet.corentinpradier.com

; <<>> DiG 9.18.39-0ubuntu0.24.04.5-Ubuntu <<>> @172.20.20.30 intranet.corentinpradier.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 32239
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 8919e60739f0f7ca010000006a1b3cc7847cd4326e0dde5a (good)
;; QUESTION SECTION:
;intranet.corentinpradier.com.  IN      A

;; AUTHORITY SECTION:
corentinpradier.com.    3600    IN      SOA     ns.corentinpradier.com. admin.corentinpradier.com. 2026052202 7200 1800 604800 3600

;; Query time: 3 msec
;; SERVER: 172.20.20.30#53(172.20.20.30) (UDP)
;; WHEN: Sat May 30 21:38:47 CEST 2026
;; MSG SIZE  rcvd: 130
```

## Client side checks

Use the CRISP employee client to verify the protected intranet view, then confirm a non-CRISP client still gets NXDOMAIN.
We do not specify address of DNS as it should be given by DHCP configuration.
Note that both clients can get the extranet website.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   extranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1:53

Name:   extranet.corentinpradier.com
Address: 120.0.40.3


t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1:53

** server can't find intranet.corentinpradier.com: NXDOMAIN

** server can't find intranet.corentinpradier.com: NXDOMAIN

t70n@t70n-workstation:~/Documents/crisp$ 
```