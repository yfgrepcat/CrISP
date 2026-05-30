# RADIUS (FreeRADIUS)

While TACACS+ is traditionally used for device administration, this lab uses FreeRADIUS to secure administrative access to the Arista vEOS routers (like P4).

### Authentication & Authorization

When a user logs in, the router sends a RADIUS 'Access-Request'. The FreeRADIUS server validates the credentials and responds with an 'Access-Accept'.

### Privilege Elevation 

Inside the "Accept-Request" message, FreeRADIUS injects an Arista-specific VSA. 
The router reads this attribute and directly places the user into privilege level 15, granting full admin rights.

### Fallback

Local fallback is configured (`aaa authentication login default group radius local`), but it only triggers if the RADIUS server is completely unreachable.

### Context

The FreeRADIUS server for our CRISP enterprise authenticates users via the `files` module (PAP / Cleartext-Password).
It runs in the official `freeradius/freeradius-server` container.
The RADIUS server is in the CRISP private services VLAN, with IP `120.0.41.11/24`.

## Files

| File          | Mounted at                                  | Purpose                              |
|---------------|---------------------------------------------|--------------------------------------|
| `clients.conf`| `/etc/raddb/clients.conf`                   | NAS clients + shared secret          |
| `authorize`   | `/etc/raddb/mods-config/files/authorize`    | User database (the two test users)   |

Shared secret for every client: `testing123`.

Allowed NAS/source networks:

- `10.12.30.0/24` (CRISP employee client net)
- `192.168.1.10/32` (nomad VPN CPE)

Server config: 

```sh
docker exec -it clab-enterprise-ospf-bgp-radius freeradius -X
```

The output of the configuration is too long to be added in this readme. Please run the command yourself if you are interested in the result.

## Users

| User  | Password   |
|-------|------------|
| alice | `alice123` |
| bob   | `bob123`   |

## Testing

From the CRISP employee client (`CRISP-CLIENT`), once the lab is deployed:

```sh
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest alice alice123 120.0.41.11 0 testing123
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest bob   bob123   120.0.41.11 0 testing123
```

Expected: 

```bash
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest alice alice123 120.0.41.11 0 testing123
Sent Access-Request Id 155 from 0.0.0.0:33680 to 120.0.41.11:1812 length 75
        User-Name = "alice"
        User-Password = "alice123"
        NAS-IP-Address = 172.20.20.56
        NAS-Port = 0
        Cleartext-Password = "alice123"
Received Access-Accept Id 155 from 120.0.41.11:1812 to 10.12.30.136:33680 length 106
        Message-Authenticator = 0xcfeb045441d6b095ad657aaec5b9bc6f
        Arista-AVPair = "shell:priv-lvl=15"
        Reply-Message = "Hello alice, authenticated by AS12 RADIUS"

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest bob   bob123   120.0.41.11 0 testing123
Sent Access-Request Id 165 from 0.0.0.0:50900 to 120.0.41.11:1812 length 73
        User-Name = "bob"
        User-Password = "bob123"
        NAS-IP-Address = 172.20.20.56
        NAS-Port = 0
        Cleartext-Password = "bob123"
Received Access-Accept Id 165 from 120.0.41.11:1812 to 10.12.30.136:50900 length 104
        Message-Authenticator = 0x95fcf144ae9e028cf8973e72f2b6f83a
        Arista-AVPair = "shell:priv-lvl=15"
        Reply-Message = "Hello bob, authenticated by AS12 RADIUS"
```

## Packet capture

Run the capture first, then launch the auth tests:

```bash
sudo tcpdump -ni net-crisp-srv -s 0 -w rsc/wireshark/radius/radius-auth.pcap 'udp port 1812 or udp port 1813'
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest alice alice123 120.0.41.11 0 testing123
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest bob   bob123   120.0.41.11 0 testing123
```
