# DHCP services

In our lab, DHCP is how machines from PE-NOMAD and CRISP Enterprise employees get their IP addresses, default gateway, and DNS server.
The AS12 server answers the normal client side, and the CRISP server answers the private CRISP client net through a relay.

This folder groups the lab's DHCP configurations by network:
- [as12-dhcp/README.md](as12-dhcp/README.md) for the central AS12 DHCP service
- [crisp-dhcp/README.md](crisp-dhcp/README.md) for the CRISP DMZ DHCP service

## Packet capture

DHCP follows the Discover, Offer, Request, Ack normal flow, and in our lab the relay forwards the request to the right server so the client gets the right lease for its network.

To confirm it, you can find a Wireshark capture in the /rsc/wireshark/dhcp folder or run the following tcpdump commands yourself:

Run the capture in one terminal, then renew a lease in another:

```bash
sudo tcpdump -ni dhcp-net -s 0 -w rsc/wireshark/dhcp/as12-dhcp.pcap 'udp port 67 or udp port 68'
sudo tcpdump -ni net-crisp-srv -s 0 -w rsc/wireshark/dhcp/crisp-dhcp.pcap 'udp port 67 or udp port 68'
docker exec clab-enterprise-ospf-bgp-NOMAD-CLIENT sh -lc 'udhcpc -i eth1 -q -n'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT sh -lc 'udhcpc -i eth1 -q -n'
```
