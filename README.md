# Enterprise Network

![Logo](rsc/logo.png)

> Multi-site enterprise network project with internal routing, interconnection with other autonomous systems, and shared network services.

> **Yoann François - Corentin Pradier - Emilien Fieu - Thomas Silvestre - Nikita Ziuzin - Stéphane Loppinet - Ismail Al Riyami - Pierre Chaveroux**

## Project Overview

This project focuses on building a multi-site enterprise network and setting up an autonomous system that can interconnect with the other ASes used by the class.

### Scope and Project Tracking

| Area | Requirements | Status |
| --- | --- | --- |
| Our AS | Provide Internet access service to individual users (internal and external). | OK |
| Our AS | Offer a zero-configuration interconnection solution for residential clients. | OK |
| Our AS | Internal residential users are our responsibility; client management is handled by the group. | OK |
| Our AS | Residential users (internal or external) must access the network through a consumer gateway (box). | OK |
| Our AS | The internal user is number 2 | OK |
| External AS | The external user is number (2+2)%4 = 0+1, , i.e., AS11 | NOK |
| Our AS | Through their gateway, residential users must be able to automatically access the enterprise network. | OK |
| Our AS | Provide Internet access service to the enterprise network (internal and external). | OK |
| Our AS | The internal company AS number is G2+10 (AS12). | OK |
| Our AS | The external company is managed by Group 3: Sarah, Denisa, Tess, Simon, Nils, Mina, Alex, Louis, and Pierre-François. | NOK |
| Our AS | The connection provided to the company must allow access to both sites: intra-AS12 and external AS13. | NOK |
| Our AS | Use OSPF as the dynamic routing protocol within the AS. | OK |
| Our AS | Our AS12 IP range is 120.0.32.0/20. | OK |
| Enterprise site | Implement network services and dynamic addressing (DHCP). | OK |
| Enterprise site | Implement internal network access security. | NOK |
| Enterprise site | Implement user management. | NOK |
| Enterprise site | Deploy the enterprise DNS service. | OK |
| Enterprise site | Deploy the VoIP service. | OK |
| Enterprise site | Deploy the company's web service. | OK |
| Enterprise site | Set up a VPN between the two company sites. | OK |
| Enterprise site | Set up a VPN between the companies and residential users. | OK |

## First launch

```bash
chmod +x set_bridges
./set_bridges

# Optional: create the extra bridges for the Arista P4 breakout trunk.
# Set TRUNK_IFACE when the host NIC is connected to a physical switch trunk.
TRUNK_IFACE=<your-host-nic> sudo -E ./scripts/create-host-bridges.sh

docker build -t reverse-proxy:latest ./web/reverse-proxy
docker build -t web:latest ./web

cd voip
make build
cd ..

# Build the local Arista vEOS image if vrnetlab/arista_veos:4.31.0F is missing.
./scripts/build-veos-image.sh

sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## Restart after a reboot

```bash
./set_bridges
TRUNK_IFACE=<your-host-nic> sudo -E ./scripts/connect-breakout-trunk.sh
sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## Arista P4 breakout trunk

`P4` runs as Arista vEOS using `configs/P4.eos.cfg`. The default local image tag is `vrnetlab/arista_veos:4.31.0F`; override it during deployment with `VEOS_IMAGE` if needed.

The physical breakout trunk uses Linux VLAN subinterfaces on one host NIC:

| VLAN | Linux interface | Host bridge | Containerlab endpoint |
| --- | --- | --- | --- |
| `104` | `clab104` | `br-vlan104` | `P4:Ethernet4` |
| `121` | `clab121` | `br-vlan121` | `PE-isp:e1-3` |
| `122` | `clab122` | `br-vlan122` | `PE-isp:e1-4` |

Run:

```bash
TRUNK_IFACE=<your-host-nic> sudo -E ./scripts/connect-breakout-trunk.sh
```

## Topology overview (Mermaid)

```mermaid
flowchart LR
	CORE["Core OSPF backbone<br/>P1-P4<br/>120.0.32.0/20"]

	PESITE["PE-site<br/>120.0.37.1"]
	PENOMAD["PE-nomad<br/>120.0.38.1"]
	PEISP["PE-isp<br/>203.0.113.1"]

	DNS["DNS (BIND9)<br/>dns-as12<br/>120.0.34.7"]
	DHCP["DHCP (dnsmasq)<br/>120.0.36.10"]
	RP["Reverse proxy / web<br/>172.20.20.34"]
	PBX["VoIP PBX (Asterisk)<br/>120.0.35.1"]

	SITEC["SITE-CLIENT<br/>DHCP: 120.0.37.0/24"]
	NOMADC["NOMAD-CLIENT<br/>DHCP: 120.0.38.0/24"]
	RESBOX["RESIDENTIAL-BOX<br/>WAN DHCP 120.0.38.x<br/>LAN 192.168.1.1/24"]

	PHONE1["phone-site<br/>120.0.35.3"]
	PHONE2["phone-nomad<br/>120.0.35.5"]

	OVPNSITE["ovpn-site<br/>10.12.20.2 + 203.0.113.50"]
	OVPNNOMAD["ovpn-nomad<br/>192.168.1.10"]
	HOMECE["home-ce (NAT)<br/>203.0.113.20 / 192.168.1.1"]
	TESTSITE["test-site<br/>10.12.20.100"]

	CORE --- PESITE
	CORE --- PENOMAD
	CORE --- PEISP
	CORE --- DNS
	CORE --- DHCP
	CORE --- RP
	CORE --- PBX

	PESITE --> SITEC
	PENOMAD --> NOMADC
	PENOMAD --> RESBOX

	PESITE -. DHCP relay .-> DHCP
	PENOMAD -. DHCP relay .-> DHCP

	PESITE --- PHONE1
	PENOMAD --- PHONE2
	PBX --- PHONE1
	PBX --- PHONE2

	PESITE --- OVPNSITE
	OVPNSITE --- TESTSITE
	PEISP --- OVPNSITE
	PEISP --- HOMECE
	HOMECE --- OVPNNOMAD
	OVPNNOMAD <-. VPN tunnel 10.255.255.1/30 <br/> 10.255.255.2/30 .-> OVPNSITE
```

How it works (short version):

- `P1-P4` is the transport core; services are attached behind PE routers or directly on core edges.
- Central DHCP (`120.0.36.10`) serves local and relayed pools; `PE-site` and `PE-nomad` relay client DHCP requests.
- DNS (`120.0.34.7`) answers with different views depending on client subnet (`120.0.37.0/24` vs `120.0.38.0/24`).
- VoIP phones register to PBX (`120.0.35.1`) and call each other across PE-site/PE-nomad.
- VPN links nomad side to HQ: `ovpn-nomad` reaches `ovpn-site` over public `203.0.113.0/24`, then into HQ LAN (`10.12.20.0/24`).

## DHCP service

The DHCP architecture, configuration details, and end-to-end test procedure are documented in [dhcp/README.md](dhcp/README.md).

## VPN service

The OpenVPN nomad CPE is documented in [vpn/README.md](vpn/README.md). 

## DNS service

The DNS architecture, views/ACL behavior, and validation commands are documented in [dns/README.md](dns/README.md).

## Web service

The web architecture and validation commands are documented in [web/README.md](web/README.md).

## VoIP service

The VoIP architecture and smoke test procedure are documented in [voip/README.md](voip/README.md).
