# OpenVPN - Nomad CPE -> HQ

This subtree contains the OpenVPN pieces of the lab. 

The model is a pre-configured nomad CPE that a user plugs into their home internet box (here: a NAT'd CE we simulate with `home-ce`). 
The CPE dials the CRISP concentrator which sits single-homed in the CRISP DMZ. 

OpenVPN makes a secure tunnel between the CPE and the DMZ listener, so the nomad side can reach the lab networks even though it sits behind the home router.

There is no dedicated public IP - the AS IGP delivers the UDP/1194 packets all the way to the DMZ listener. 

The enterprise IGP does not carry the nomad's home network.

## Files

| File          | Role |
|---------------|------|
| `openvpn/nomad.conf` | CPE config - client/initiator. `nobind`, `remote 120.0.40.2 1194`. |
| `openvpn/site.conf`  | HQ config - server/listener bound to `120.0.40.2:1194`, `float` (NAT survival). |
| `openvpn/static.key` | Shared pre-shared key for the nomad tunnel. Static-key mode = single peer. |
| `openvpn/site-branch.conf` | HQ config - recond listener on `120.0.40.2:1195` (tun1) for the remote branch. |
| `openvpn/remote-site.conf` | Remote branch gateway config - runs on the physical Ubuntu router, dials `120.0.40.2:1195`. |
| `openvpn/static-branch.key` | Shared pre-shared key for the branch tunnel (distinct from `static.key`). |

Mode is `secret` (static key, no PKI). Static-key is one peer per listener, so the nomad CPE and the remote branch each get their own listener / key / inner `/30` (`:1194` and `:1195`). 

If you ever add a third peer, migrate to TLS with per-peer certs.

`cipher none` / `auth none` is set for lab readability - packets are clear-text on the wire so you can read them in Wireshark. 

## Addressing

| Prefix              | Where                                              | In OSPF? |
|---------------------|----------------------------------------------------|----------|
| `192.168.1.0/24`    | `net-home` - nomad's home LAN behind the CE        | No (opaque to everyone but `home-ce` / CPE) |
| `120.0.38.0/24`     | Residential aggregation `net-nomad` (home-ce WAN)  | Yes (passive on PE-nomad) |
| `120.0.37.0/24`     | Enterprise client LAN on `net-site`                | Yes (passive on PE-site) |
| `120.0.40.0/24`     | CRISP DMZ on `net-crisp-dmz` (ovpn-site/proxy/web) | Yes (passive on CRISP) |
| `120.0.41.0/24`     | CRISP private services on `net-crisp-srv`     | Yes (passive on CRISP) |
| `10.12.30.0/24`     | CRISP private client net                           | Yes (passive on CRISP) |
| `10.255.255.0/30`   | Nomad tunnel inner - `.1` CPE, `.2` CRISP side     | Static on PE-site and CRISP -> `ovpn-site` (120.0.40.2) |
| `10.255.255.4/30`   | Branch tunnel inner - `.5` router, `.6` CRISP side | Static on PE-site and CRISP -> `ovpn-site` (120.0.40.2) |
| `192.168.50.0/24`   | Remote-site LAN behind the physical Ubuntu router  | Static on PE-site and CRISP -> `ovpn-site`; tunnel-only (not in BGP) |

## How it works

The nomad CPE dials the HQ listener to build a point-to-point OpenVPN tunnel (nomad uses UDP/1194). The branch uses a separate listener (UDP/1195). The CPE must initiate (it sits behind NAT); the HQ listener uses `float` to tolerate source IP/port changes. This lab uses static pre-shared keys and `cipher none`/`auth none` for visibility - do not use that setup in production.

## Tests

### 1. Tunnel up on both ends

```bash
docker exec clab-enterprise-ospf-bgp-ovpn-site  ip -br a show tun0
docker exec clab-enterprise-ospf-bgp-ovpn-nomad ip -br a show tun0
```

You should see `10.255.255.2/32` (HQ) and `10.255.255.1/32` (nomad).

Expected:

```bash
t70n@t70n-workstation:~/Documents/crisp/voip$ docker exec clab-enterprise-ospf-bgp-ovpn-site  ip -br a show tun0
tun0             UNKNOWN        10.255.255.2 peer 10.255.255.1/32 fe80::fcdc:a1bc:ac21:3f48/64 
t70n@t70n-workstation:~/Documents/crisp/voip$ docker exec clab-enterprise-ospf-bgp-ovpn-nomad ip -br a show tun0
tun0             UNKNOWN        10.255.255.1 peer 10.255.255.2/32 fe80::a767:592d:3c4f:1a2a/64
```

### 3. CPE reaches an HQ host

The reverse-proxy lives in the CRISP DMZ at `120.0.40.3`. From the CPE:

```bash
docker exec clab-enterprise-ospf-bgp-ovpn-nomad ping -c 3 120.0.40.3   # DMZ (web/proxy/PBX)
docker exec clab-enterprise-ospf-bgp-ovpn-nomad ping -c 3 10.12.30.1   # CRISP client-net gateway
docker exec clab-enterprise-ospf-bgp-ovpn-nomad nslookup intranet.corentinpradier.com
docker exec clab-enterprise-ospf-bgp-ovpn-nomad wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3
```

The CPE pulls `120.0.40.0/24` and `10.12.30.0/24` over the tunnel (see
`openvpn/nomad.conf`). The return path uses the CRISP static
`10.255.255.0/30 -> 120.0.40.2` (`ovpn-site` DMZ leg), which sends the reply
back into the tunnel.

The tunnel also carries `120.0.36.1` so the nomad CPE can resolve the
intranet hostname before reaching the protected web vhost.

The protected intranet lookup should succeed from the VPN CPE and the CRISP
employee client, but not from `NOMAD-CLIENT`.

```bash
docker exec clab-enterprise-ospf-bgp-ovpn-nomad sh -lc 'nslookup intranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-ovpn-nomad sh -lc 'wget -qO- --header="Host: intranet.corentinpradier.com" http://120.0.40.3
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'nslookup intranet.corentinpradier.com'
```

### 4. Capture the encapsulation

Capture the outer UDP on both ends, then run the ping tests:

```bash
sudo tcpdump -ni net-nomad -s 0 -w rsc/wireshark/vpn-nomad-outer.pcap 'udp port 1194'
sudo tcpdump -ni net-crisp-dmz -s 0 -w rsc/wireshark/vpn-nomad-listener.pcap 'udp port 1194'
```
