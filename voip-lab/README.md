# VoIP Lab

Asterisk PBX + 2 baresip softphones integrated into the enterprise OSPF topology.

## Architecture

```
phone-site  (ext. 1001) ── PE-site  ──┐
                                       ├── P4 ── pbx (Asterisk :5060)
phone-nomad (ext. 1002) ── PE-nomad ──┘
```

| Node | SIP ext | Password |
|---|---|---|
| `pbx` | — | — |
| `phone-site` | 1001 | secret1 |
| `phone-nomad` | 1002 | secret2 |

## Deploy

```bash
# from voip-lab/
make build                           # build Docker images (required before clab)
clab deploy -t ../topology.clab.yaml
```

Container names: `clab-enterprise-ospf-bgp-<node>`

## Make a call

Both phones register automatically on deploy. Attach to a phone's baresip console:

```bash
# Terminal 1
make phone-site

# Terminal 2
make phone-nomad
```

Detach without stopping: `Ctrl+C`

From `phone-site`:
```
/dial 1002
```

`phone-nomad` will ring. Answer:
```
/accept
```

Hang up:
```
/hangup
```

## Teardown

```bash
clab destroy -t ../topology.clab.yaml
```

---

## Troubleshooting

**Registration fails** — check PBX is up: `docker logs clab-enterprise-ospf-bgp-pbx`

**No audio** — expected; `auloop` used as audio backend (loopback). Call signalling (INVITE/200 OK) still works.

**Port conflict on 5060** — stop any local SIP daemon before deploying.
