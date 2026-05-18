This folder contains the main BIND9 configuration used by the lab.

Replace placeholder identifiers (for example `ID_ENTERPRISE_RANGE`) with your target ranges and IPs.

Service IP map used by the current lab draft:
- DNS server: 120.0.34.7
- Internal web server: 120.0.35.11
- Public web server: 120.0.35.12
- VoIP server: 120.0.35.13

These are invented service IPs for the zone files so the DNS layout is complete before the real service containers are added.

BIND views let the server match the source IP (DHCP-assigned ranges) and serve a different zone file per view. 

Use match-clients { ... } with your DHCP ranges (replace ID_* placeholders).

For inter-AS exchange, configure allow-transfer and also-notify or use forwarding to peer DNS IP(s) (ID_AS_PEER_DNS_IP) inside the zone and options files.

In containerlab the BIND container is attached to the relevant host bridges so it can see queries from enterprise and residential segments.

Deployment steps (quick)

Edit the placeholder IDs in the dns files:
Replace ID_ENTERPRISE_RANGE, ID_ENTERPRISE_RANGE_2, ID_CLIENT1_RANGE, ID_CLIENT2_RANGE with your DHCP CIDRs.
Replace ID_DNS_AS12_IP, ID_WEB_SERVER_IP, ID_VOIP_SERVER_IP, ID_WEB_SERVER_PUBLIC_IP, ID_AS_PEER_DNS_IP, ID_UPSTREAM_FORWARDER with real IPs.
If you keep the draft values above, the current zone files already resolve the DNS, web, and VoIP names to those service IPs.
The main topology already includes the DNS service node and link.
Deploy the lab (example):
# from repository root
sudo containerlab deploy --topo topology.clab.yaml
Inside the BIND container (if you need to debug):
# find container name, then:
docker exec -it <dns-as12-container> bash
named-checkconf /etc/bind/named.conf
named-checkzone enterprise.local /etc/bind/zones/db.enterprise.local
journalctl -u bind9    # or check container logs