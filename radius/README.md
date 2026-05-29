# RADIUS (FreeRADIUS)

FreeRADIUS server for our CRISP enterprise. Authenticates users via the `files` module (PAP / Cleartext-Password).
Runs in the official `freeradius/freeradius-server` container.
Radius server is in the CRISP private services VLAN, with IP `120.0.41.11/24`.

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
Sent Access-Request Id 209 from 0.0.0.0:53960 to 120.0.41.11:1812 length 75
        User-Name = "alice"
        User-Password = "alice123"
        NAS-IP-Address = 172.20.20.56
        NAS-Port = 0
        Cleartext-Password = "alice123"
Received Access-Accept Id 209 from 120.0.41.11:1812 to 10.12.30.182:53960 length 106
        Message-Authenticator = 0x924e7efc0e9d9c0c26e8f02631b6c351
        Arista-AVPair = "shell:priv-lvl=15"
        Reply-Message = "Hello alice, authenticated by AS12 RADIUS"

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest bob   bob123   120.0.41.11 0 testing123
Sent Access-Request Id 219 from 0.0.0.0:59656 to 120.0.41.11:1812 length 73
        User-Name = "bob"
        User-Password = "bob123"
        NAS-IP-Address = 172.20.20.56
        NAS-Port = 0
        Cleartext-Password = "bob123"
Received Access-Accept Id 219 from 120.0.41.11:1812 to 10.12.30.182:59656 length 104
        Message-Authenticator = 0xe756430fc2c56a57b3a8894790421cc9
        Arista-AVPair = "shell:priv-lvl=15"
        Reply-Message = "Hello bob, authenticated by AS12 RADIUS"

t70n@t70n-workstation:~/Documents/crisp$ 
```
