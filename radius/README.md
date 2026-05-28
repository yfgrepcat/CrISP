# RADIUS (FreeRADIUS)

Minimal FreeRADIUS server for the AS12 enterprise lab. Authenticates users via
the `files` module (PAP / Cleartext-Password). Runs in the official
`freeradius/freeradius-server` container.

## Topology

- Node `radius`, hung off **P2** on `ethernet-1/5`.
- P2P link `120.0.34.10/31`: P2 `.10`, RADIUS `.11`.
- mgmt IP `172.20.20.36`.
- Listens on UDP **1812** (auth) / **1813** (acct).

The service is not in the CRISP service VLAN. It is a shared AS12 service on the P2 service link, reachable from the CRISP employee subnet `10.12.30.0/24` and the rest of AS12.

## Files

| File          | Mounted at                                  | Purpose                              |
|---------------|---------------------------------------------|--------------------------------------|
| `clients.conf`| `/etc/raddb/clients.conf`                   | NAS clients + shared secret          |
| `authorize`   | `/etc/raddb/mods-config/files/authorize`    | User database (the two test users)   |

Shared secret for every client: `testing123`.

Allowed NAS/source networks:

- `120.0.32.0/20` (AS12 IGP)
- `10.12.30.0/24` (CRISP employee client net)
- `172.20.20.0/24` (management network)

## Users

| User  | Password   |
|-------|------------|
| alice | `alice123` |
| bob   | `bob123`   |

## Testing

From the mgmt host (`radtest` ships with the freeradius client tools):

```sh
# from inside the radius container, or any AS12 host that can reach 120.0.34.11
radtest alice alice123 120.0.34.11 0 testing123
radtest bob   bob123   120.0.34.11 0 testing123
```

From the CRISP employee client (`CRISP-CLIENT`), once the lab is deployed:

```sh
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest alice alice123 120.0.34.11 0 testing123
docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest bob   bob123   120.0.34.11 0 testing123
```

Expect `Access-Accept` with the `Reply-Message`. A wrong password yields
`Access-Reject`.

To debug interactively, stop the daemon and run it in the foreground:

```sh
docker exec -it clab-enterprise-ospf-bgp-radius freeradius -X
```

t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest alice alice123 120.0.34.11 0 testing123
Sent Access-Request Id 168 from 0.0.0.0:58688 to 120.0.34.11:1812 length 75
        User-Name = "alice"
        User-Password = "alice123"
        NAS-IP-Address = 172.20.20.56
        NAS-Port = 0
        Cleartext-Password = "alice123"
Received Access-Accept Id 168 from 120.0.34.11:1812 to 10.12.30.119:58688 length 106
        Message-Authenticator = 0x8e13545f4fd6392f5ccb1dd4e6daedc4
        Arista-AVPair = "shell:priv-lvl=15"
        Reply-Message = "Hello alice, authenticated by AS12 RADIUS"
t70n@t70n-workstation:~/Documents/crisp$ docker exec clab-enterprise-ospf-bgp-CRISP-CLIENT radtest bob bob123 120.0.34.11 0 testing123
Sent Access-Request Id 175 from 0.0.0.0:49180 to 120.0.34.11:1812 length 73
        User-Name = "bob"
        User-Password = "bob123"
        NAS-IP-Address = 172.20.20.56
        NAS-Port = 0
        Cleartext-Password = "bob123"
Received Access-Accept Id 175 from 120.0.34.11:1812 to 10.12.30.119:49180 length 104
        Message-Authenticator = 0xcc336bc977cecfa0fcd99130a4945c4f
        Arista-AVPair = "shell:priv-lvl=15"
        Reply-Message = "Hello bob, authenticated by AS12 RADIUS"
t70n@t70n-workstation:~/Documents/crisp$ 