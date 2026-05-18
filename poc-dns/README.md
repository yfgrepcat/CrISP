This folder is a small proof-of-concept lab for validating DNS in Containerlab.

Prerequisites:
- Docker installed
- `containerlab` installed on the host

Quick install on supported Linux systems:

```bash
curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"
```

Topology:
- DNS server: `dns`
- Client: `client`
- Shared subnet: `172.16.10.0/24`

Usage:

```bash
sudo containerlab deploy --topo poc-dns.clab.yaml
docker exec -it clab-dns-poc-client bash
dig @172.16.10.53 host.poc.lab
```

The lab now uses a direct link between the two containers, so no host bridge needs to be created first.
