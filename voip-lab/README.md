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

ContainerLab requires a Linux host — no prebuilt binary for macOS ARM64. Use `make up` on macOS for local development.

### Install clab

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
```

### Deploy

```bash
make deploy       # builds images then runs: clab deploy -t topology.clab.yml
```

Container names are prefixed by clab: `clab-voip-pbx`, `clab-voip-phone1`, `clab-voip-phone2`.

### Attach to a phone

```bash
make clab-phone1  # docker attach clab-voip-phone1
make clab-phone2  # docker attach clab-voip-phone2
```

Same baresip commands apply (`/dial 1002`, `/accept`, `/hangup`). Detach: `Ctrl+C`.

### Teardown

```bash
make destroy      # removes containers and clab-managed network interfaces
```

---

## Troubleshooting

**Registration fails** — check PBX is up: `docker logs voip-pbx`

**No audio** — expected in this setup; `auloop` is used as audio backend (loopback, no real mic/speaker required). Call signalling (INVITE/200 OK) still works.

**Port conflict on 5060** — stop any local SIP daemon before running `make up`.
