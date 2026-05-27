# RADIUS (FreeRADIUS)

Minimal FreeRADIUS server for the AS12 enterprise lab. Authenticates users via
the `files` module (PAP / Cleartext-Password). Runs in the official
`freeradius/freeradius-server` container.

## Topology

- Node `radius`, hung off **P2** on `ethernet-1/5`.
- P2P link `120.0.34.10/31`: P2 `.10`, RADIUS `.11`.
- mgmt IP `172.20.20.36`.
- Listens on UDP **1812** (auth) / **1813** (acct).

## Files

| File          | Mounted at                                  | Purpose                              |
|---------------|---------------------------------------------|--------------------------------------|
| `clients.conf`| `/etc/raddb/clients.conf`                   | NAS clients + shared secret          |
| `authorize`   | `/etc/raddb/mods-config/files/authorize`    | User database (the two test users)   |

Shared secret for every client: `testing123`.

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

Expect `Access-Accept` with the `Reply-Message`. A wrong password yields
`Access-Reject`.

To debug interactively, stop the daemon and run it in the foreground:

```sh
docker exec -it clab-enterprise-ospf-bgp-radius freeradius -X
```
