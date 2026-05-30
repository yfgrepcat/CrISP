# Web service

Simple web architecture with one reverse proxy and one backend web server.

The reverse proxy reads the Host header, sends public requests to the public page, and only lets the intranet page through for the allowed source nets.

## How it works

- `reverse-proxy` is the entry point.
- Public hostname: `extranet.corentinpradier.com` (public page).
- Intranet hostname: `intranet.corentinpradier.com` (restricted by source subnet).
- Backend content is served by `web-server`:
  - public site on port `80`
  - intranet site on port `6767`

In this topology:

- Reverse proxy mgmt IP: `172.20.20.34`
- Reverse proxy service-side IP: `120.0.40.3/24`
- Web server IP: `120.0.40.4/24`
- DNS server for tests: `120.0.36.1`

## Packet capture

Capture the HTTP traffic while you run the public and intranet tests:

```bash
sudo tcpdump -ni net-crisp-dmz -s 0 -w rsc/wireshark/web-http.pcap 'tcp port 80 or tcp port 6767'
```

## Tests

### Public website

The public site should be reachable by IP and by DNS.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: extranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
```

Expected: 

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
    <h1>Page web des fans de Corentin Pradier, également connu sous le nom cocoaligot12 (12 comme l'aveyron)</h1>

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   extranet.corentinpradier.com
Address: 120.0.40.3
```

### Intranet website

The intranet site should be reachable only from allowed enterprise/private ranges.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Connexion Intranet"'
```

Expected: 

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Connexion Intranet"'
            <h2>Connexion Intranet</h2>
t70n@t70n-workstation:~/Documents/crisp$ 
```
