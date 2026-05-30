# DNS service

In our lab, DNS is split in two parts: the AS12 resolver answers our own zone and does the normal lookups, while the root server keeps the delegations that let every AS find the others.

DNS starts from the local resolver, and when it does not know the answer it walks the root delegation chain until it finds the right authoritative server.

This folder groups the lab DNS configuration by role:
- [as12-dns/README.md](as12-dns/README.md) for the AS12 resolver, views, and zones
- [root-dns/README.md](root-dns/README.md) for the lab root nameserver

## Architecture overview

Two BIND9 nameservers:

| Node | Role | Service IP | Mgmt IP | Container name |
| --- | --- | --- | --- | --- |
| `dns-as12` | AS12 authoritative resolver (views) | `120.0.36.1/31` | `clab-enterprise-ospf-bgp-dns-as12` |
| `dns-root` | Lab root nameserver (sync point for inter-AS DNS) | `120.0.36.5/31` | `clab-enterprise-ospf-bgp-dns-root` |

`dns-as12` config is split by views in `as12-dns/views.conf` (loaded by `as12-dns/named.conf`).
`dns-root` is a separate, authoritative server for `.` configured under `root-dns/`.

## Packet capture

Run the captures in separate terminals, then trigger the lookups with the existing `dig` tests:

```bash
sudo tcpdump -ni dns-net -s 0 -w rsc/wireshark/dns/as12-dns.pcap udp port 53
sudo tcpdump -ni any -s 0 -w rsc/wireshark/dns/root-dns.pcap 'host 120.0.36.5 and udp port 53'
```
