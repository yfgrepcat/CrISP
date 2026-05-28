# DNS service

## Architecture overview

The DNS server is `dns-as12` (BIND9) connected to the P1 service LAN.

- DNS container name: `clab-enterprise-ospf-bgp-dns-as12`
- DNS mgmt IP: `172.20.20.30`
- DNS service IP: `120.0.36.1/31`

The BIND config is split by views in `dns/views.conf`.

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