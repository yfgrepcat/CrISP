# Web service

Simple web architecture with one reverse proxy and one backend web server.

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

## Tests

### Public website

The public site should be reachable by IP and by DNS.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: extranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
```

Expected: 

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
    <h1>Page web des fans de Corentin Pradier, également connu sous le nom cocoaligot12 (12 comme l'aveyron)</h1>
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com 120.0.36.1'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   extranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup extranet.corentinpradier.com'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   extranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: extranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Page web des fans de Corentin Pradier"'
    <h1>Page web des fans de Corentin Pradier, également connu sous le nom cocoaligot12 (12 comme l'aveyron)</h1>
t70n@t70n-workstation:~/Documents/crisp$ 
```

### Intranet website

The intranet site should be reachable only from allowed enterprise/private ranges.

```bash
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Connexion Intranet"'
```

Expected: 

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com 120.0.36.1'
Server:         120.0.36.1
Address:        120.0.36.1#53

Name:   intranet.corentinpradier.com
Address: 120.0.40.3

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3 | grep -m1 "Connexion Intranet"'
            <h2>Connexion Intranet</h2>
t70n@t70n-workstation:~/Documents/crisp$ 
```

## Quick debug

```bash
docker logs clab-enterprise-ospf-bgp-reverse-proxy | tail -n 100
docker logs clab-enterprise-ospf-bgp-web-server | tail -n 100
```

Expected: 

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker logs clab-enterprise-ospf-bgp-reverse-proxy | tail -n 100
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
20-envsubst-on-templates.sh: Running envsubst on /etc/nginx/templates/reverse-proxy.conf.template to /etc/nginx/conf.d/reverse-proxy.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/05/28 22:48:15 [notice] 1#1: using the "epoll" event method
2026/05/28 22:48:15 [notice] 1#1: nginx/1.31.1
2026/05/28 22:48:15 [notice] 1#1: built by gcc 15.2.0 (Alpine 15.2.0) 
2026/05/28 22:48:15 [notice] 1#1: OS: Linux 6.17.0-29-generic
2026/05/28 22:48:15 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2026/05/28 22:48:15 [notice] 1#1: start worker processes
2026/05/28 22:48:15 [notice] 1#1: start worker process 36
2026/05/28 22:48:15 [notice] 1#1: start worker process 37
2026/05/28 22:48:15 [notice] 1#1: start worker process 38
2026/05/28 22:48:15 [notice] 1#1: start worker process 39
2026/05/28 22:48:15 [notice] 1#1: start worker process 40
2026/05/28 22:48:15 [notice] 1#1: start worker process 41
2026/05/28 22:48:15 [notice] 1#1: start worker process 42
2026/05/28 22:48:15 [notice] 1#1: start worker process 43
2026/05/28 22:48:15 [notice] 1#1: start worker process 44
2026/05/28 22:48:15 [notice] 1#1: start worker process 45
2026/05/28 22:48:15 [notice] 1#1: start worker process 46
2026/05/28 22:48:15 [notice] 1#1: start worker process 47
2026/05/28 22:48:15 [notice] 1#1: start worker process 48
2026/05/28 22:48:15 [notice] 1#1: start worker process 49
2026/05/28 22:48:15 [notice] 1#1: start worker process 50
2026/05/28 22:48:15 [notice] 1#1: start worker process 51
2026/05/28 22:48:15 [notice] 1#1: start worker process 52
2026/05/28 22:48:15 [notice] 1#1: start worker process 53
2026/05/28 22:48:15 [notice] 1#1: start worker process 54
2026/05/28 22:48:15 [notice] 1#1: start worker process 55
10.12.30.110 - - [28/May/2026:23:02:34 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
10.12.30.110 - - [28/May/2026:23:02:34 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
10.12.30.110 - - [28/May/2026:23:02:59 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
10.12.30.110 - - [28/May/2026:23:03:26 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
10.12.30.110 - - [28/May/2026:23:05:12 +0000] "GET / HTTP/1.1" 200 1458 "-" "Wget" "-"

t70n@t70n-workstation:~/Documents/crisp$ docker logs clab-enterprise-ospf-bgp-web-server | tail -n 100
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: /etc/nginx/conf.d/default.conf is not a file or does not exist
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/05/28 22:48:15 [notice] 1#1: using the "epoll" event method
2026/05/28 22:48:15 [notice] 1#1: nginx/1.31.1
2026/05/28 22:48:15 [notice] 1#1: built by gcc 15.2.0 (Alpine 15.2.0) 
2026/05/28 22:48:15 [notice] 1#1: OS: Linux 6.17.0-29-generic
2026/05/28 22:48:15 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2026/05/28 22:48:15 [notice] 1#1: start worker processes
2026/05/28 22:48:15 [notice] 1#1: start worker process 20
2026/05/28 22:48:15 [notice] 1#1: start worker process 21
2026/05/28 22:48:15 [notice] 1#1: start worker process 22
2026/05/28 22:48:15 [notice] 1#1: start worker process 23
2026/05/28 22:48:15 [notice] 1#1: start worker process 24
2026/05/28 22:48:15 [notice] 1#1: start worker process 25
2026/05/28 22:48:15 [notice] 1#1: start worker process 26
2026/05/28 22:48:15 [notice] 1#1: start worker process 27
2026/05/28 22:48:15 [notice] 1#1: start worker process 28
2026/05/28 22:48:15 [notice] 1#1: start worker process 29
2026/05/28 22:48:15 [notice] 1#1: start worker process 30
2026/05/28 22:48:15 [notice] 1#1: start worker process 31
2026/05/28 22:48:15 [notice] 1#1: start worker process 32
2026/05/28 22:48:15 [notice] 1#1: start worker process 33
2026/05/28 22:48:15 [notice] 1#1: start worker process 34
2026/05/28 22:48:15 [notice] 1#1: start worker process 35
2026/05/28 22:48:15 [notice] 1#1: start worker process 36
2026/05/28 22:48:15 [notice] 1#1: start worker process 37
2026/05/28 22:48:15 [notice] 1#1: start worker process 38
2026/05/28 22:48:15 [notice] 1#1: start worker process 39
172.20.20.34 - - [28/May/2026:23:02:34 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
172.20.20.34 - - [28/May/2026:23:02:34 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
172.20.20.34 - - [28/May/2026:23:02:59 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
172.20.20.34 - - [28/May/2026:23:03:26 +0000] "GET / HTTP/1.1" 200 368 "-" "Wget" "-"
172.20.20.34 - - [28/May/2026:23:05:12 +0000] "GET / HTTP/1.1" 200 1458 "-" "Wget" "-"
t70n@t70n-workstation:~/Documents/crisp$ 
```