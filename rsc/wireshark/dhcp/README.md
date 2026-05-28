# DHCP captures

Files in this folder:
- dhcp-server-only.pcap — server-side capture (UDP ports 67/68).
- clab-enterprise-ospf-bgp-SITE-CLIENT.pcap — (historical) SITE client capture; SITE-CLIENT node removed from topology.
- clab-enterprise-ospf-bgp-NOMAD-CLIENT.pcap — NOMAD client capture.
- clab-enterprise-ospf-bgp-RESIDENTIAL-BOX.pcap — residential box capture.

What to look for in the captures
- Use Wireshark filter: `dhcp` or `bootp`.
- Typical sequence: DISCOVER, OFFER, REQUEST, ACK.
- Verify: DHCP Message Type, Gateway IP (`giaddr`), Server Identifier, Requested IP / Your IP.

Quick command
- View a text summary: `tcpdump -nn -r dhcp-server-only.pcap -vv | less`