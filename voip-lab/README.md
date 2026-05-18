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

## Troubleshooting

**Registration fails** — check PBX is up: `docker logs voip-pbx`

**No audio** — expected in this setup; `auloop` is used as audio backend (loopback, no real mic/speaker required). Call signalling (INVITE/200 OK) still works.

**Port conflict on 5060** — stop any local SIP daemon before running `make up`.
