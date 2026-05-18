# VoIP Lab

Asterisk PBX + 2 baresip softphones, all running in Docker.

## Architecture

```
phone1 (baresip) ──┐
                   ├── voip bridge ── pbx (Asterisk :5060)
phone2 (baresip) ──┘
```

| Container  | Image         | SIP ext | Password  |
|------------|---------------|---------|-----------|
| `voip-pbx` | asterisk      | —       | —         |
| `voip-phone1` | baresip    | 1001    | secret1   |
| `voip-phone2` | baresip    | 1002    | secret2   |

## Start

```bash
make up
```

Builds images and starts all 3 containers in the background.

## Make a call

Both phones register automatically on `make up`. Attach to a phone's baresip console (two terminals):

```bash
# Terminal 1
make phone1

# Terminal 2
make phone2
```

Detach without stopping: `Ctrl+C`

Once attached, dial from phone1:

```
/dial 1002
```

Phone2 will ring. Answer:

```
/accept
```

Hang up:

```
/hangup
```

Type `/quit` to exit the baresip shell without stopping the container.

## Stop

```bash
make down
```

## ContainerLab (Linux only)

VoIP nodes (`pbx`, `phone-site`, `phone-nomad`) are integrated into the main enterprise topology at the repo root. ContainerLab requires a Linux host — no prebuilt binary for macOS ARM64.

### Build images then deploy

```bash
# from voip-lab/
make build                          # build Docker images
clab deploy -t ../topology.clab.yaml
```

Container names: `clab-enterprise-ospf-bgp-<node>`
- `clab-enterprise-ospf-bgp-pbx`
- `clab-enterprise-ospf-bgp-phone-site`   (ext. 1001 — intranet via PE-site)
- `clab-enterprise-ospf-bgp-phone-nomad`  (ext. 1002 — external via PE-nomad)

### Attach to a phone

```bash
make clab-phone1   # phone-site
make clab-phone2   # phone-nomad
```

Same baresip commands apply (`/dial 1002`, `/accept`, `/hangup`). Detach: `Ctrl+C`.

### Teardown

```bash
clab destroy -t ../topology.clab.yaml
```

---

## Troubleshooting

**Registration fails** — check PBX is up: `docker logs voip-pbx`

**No audio** — expected in this setup; `auloop` is used as audio backend (loopback, no real mic/speaker required). Call signalling (INVITE/200 OK) still works.

**Port conflict on 5060** — stop any local SIP daemon before running `make up`.
