# Root DNS service

This is the lab root server. It does not hold the AS12 zone itself; it only keeps the NS links and glue so the other resolvers can find it.

DNS here is just the delegation step: it gives the NS and glue records that point other resolvers to the right authoritative server.

This folder contains the lab root nameserver configuration:
- `named.conf`
- `named.conf.options`
- `db.root`

The container mounts this directory at `/etc/bind` so BIND can serve `.` and the AS delegation glue from `db.root`.

### Lab root DNS - the inter-AS sync point

Each AS keeps its own authoritative zone (we keep `corentinpradier.com`). To resolve a peer AS's zone without depending on that peer's resolver being up - and to avoid bring-up order coupling - every AS resolver iterates from a shared root: `dns-root` (`120.0.36.5/31`). The root only holds NS delegations + glue, one entry per AS.

```
clients --> dns-as12 (recursive, views) --> dns-root (.)
                                              |- corentinpradier.com.  --> 120.0.36.1  (AS12)
                                              |- <as11-zone>.          --> <as11-ip>   (TODO)
                                              |- <as13-zone>.          --> 120.0.48.34 (TODO)
                                              |- <as14-zone>.          --> <as14-ip>   (TODO)
```

Reachability today: `dns-root` sits on the dedicated `120.0.36.4/31` link off `P2`, advertised as a passive OSPF interface so every internal node can reach it.

Adding a peer AS: (one block in `../root-dns/db.root`):

```bind
<peer-zone>.    IN NS    ns.<peer-zone>.
ns.<peer-zone>. IN A     <peer-dns-ip>
```

### Verify the root chain

```bash
# 1. dns-root is reachable + authoritative for `.`
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 . SOA +norec
#    -> answer with AA flag, SOA root-srv.lab. admin.lab. ...

# 2. dns-root delegates our zone (NS + glue)
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 corentinpradier.com NS +norec
#    -> AUTHORITY: corentinpradier.com. NS ns.corentinpradier.com.
#    -> ADDITIONAL: ns.corentinpradier.com. A 120.0.36.1

# 3. dns-as12 can still resolve the root and its glue
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 root-srv.lab A +norec
docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 ns.n7. A +norec

# 4. End-to-end iterative path for the delegated peer AS we already publish:
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'dig @120.0.36.1 n7. NS +norec'
#    -> resolves via dns-as12 -> dns-root -> delegation + glue
```

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 . SOA +norec

; <<>> DiG 9.21.21 <<>> @120.0.36.5 . SOA +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 35046
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 47b19d60ac83e62e010000006a1b3e2eea6699fcf3a0b51b (good)
;; QUESTION SECTION:
;.                              IN      SOA

;; ANSWER SECTION:
.                       86400   IN      SOA     root-srv.lab. admin.lab. 2026052901 7200 1800 604800 86400

;; Query time: 73 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Sat May 30 19:44:46 UTC 2026
;; MSG SIZE  rcvd: 109

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 corentinpradier.com NS +norec

; <<>> DiG 9.21.21 <<>> @120.0.36.5 corentinpradier.com NS +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 32957
;; flags: qr; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: e3d271909d016b5b010000006a1b3e3226a3d4576a74138c (good)
;; QUESTION SECTION:
;corentinpradier.com.           IN      NS

;; AUTHORITY SECTION:
corentinpradier.com.    86400   IN      NS      ns.corentinpradier.com.

;; ADDITIONAL SECTION:
ns.corentinpradier.com. 86400   IN      A       120.0.36.1

;; Query time: 2 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Sat May 30 19:44:50 UTC 2026
;; MSG SIZE  rcvd: 109

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 root-srv.lab A +norec

; <<>> DiG 9.21.21 <<>> @120.0.36.5 root-srv.lab A +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 63185
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 64488ba75be5a888010000006a1b3e3664d233579ed31cfa (good)
;; QUESTION SECTION:
;root-srv.lab.                  IN      A

;; ANSWER SECTION:
root-srv.lab.           86400   IN      A       120.0.36.5

;; Query time: 2 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Sat May 30 19:44:54 UTC 2026
;; MSG SIZE  rcvd: 85

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-dns-as12 dig @120.0.36.5 ns.n7. A +norec

; <<>> DiG 9.21.21 <<>> @120.0.36.5 ns.n7. A +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 63503
;; flags: qr; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: b65416e13792ae1b010000006a1b3e3b92ba3a872031c017 (good)
;; QUESTION SECTION:
;ns.n7.                         IN      A

;; AUTHORITY SECTION:
n7.                     86400   IN      NS      ns.n7.

;; ADDITIONAL SECTION:
ns.n7.                  86400   IN      A       120.0.30.1

;; Query time: 2 msec
;; SERVER: 120.0.36.5#53(120.0.36.5) (UDP)
;; WHEN: Sat May 30 19:44:59 UTC 2026
;; MSG SIZE  rcvd: 92

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'dig @120.0.36.1 n7. NS +norec'

; <<>> DiG 9.20.23 <<>> @120.0.36.1 n7. NS +norec
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 59005
;; flags: qr ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: d604d06718b249ac010000006a1b3e3fb3d2ae1c0645d391 (good)
;; QUESTION SECTION:
;n7.                            IN      NS

;; AUTHORITY SECTION:
.                       86400   IN      NS      root-srv.lab.

;; Query time: 3 msec
;; SERVER: 120.0.36.1#53(120.0.36.1) (UDP)
;; WHEN: Sat May 30 19:45:03 UTC 2026
;; MSG SIZE  rcvd: 84
```

The iterative chain only has anything to iterate to once at least one peer AS publishes its delegation in `../root-dns/db.root`; `n7.` is the current example. 
The AS12 zone is answered locally by the matching view and never reach the root.
