# VoIP

SIP call flow with one Asterisk PBX (server) and 2 softphones (clients).

## Architecture

### Files

```
voip/
  Makefile                    Build both Docker images; attach to phone consoles.
  asterisk/
    Dockerfile                Builds the Asterisk PBX image (asterisk + config).
    sip.conf                  SIP peer definitions — ext. 1001 (phone-crisp1) and 1002
                              (phone-crisp2), dynamic host, ulaw/alaw codecs.
    extensions.conf           Dial plan — Dial(SIP/100x, 30s) for each extension.
  client/
    Dockerfile                Builds the baresip softphone image.
    entrypoint.sh             Auto-configures baresip at startup: reads SIP_USER /
                              SIP_SERVER / SIP_PASS env vars, detects local IP on
                              eth1, writes accounts + config, then registers to PBX.
```

### Network topology

![architecture PBX softphones](resources/archi.png)

The PBX runs in the CRISP DMZ (`120.0.40.5/24`). Both phones sit in the CRISP LAN (`10.12.30.0/24`) and reach the PBX through the CRISP router.

## How it works

- `pbx` runs Asterisk with SIP users `1001` and `1002`
- `phone-crisp1` registers as `1001` to `voip.corentinpradier.com`
- `phone-crisp2` registers as `1002` to `voip.corentinpradier.com`

Topology service links:

- `pbx` on `120.0.40.5/24` in the CRISP DMZ
- `phone-crisp1` on `10.12.30.101/24` via `CRISP`
- `phone-crisp2` on `10.12.30.102/24` via `CRISP`

## Registration

Phones register automatically on startup (`regint=3600`, re-registers every 3600 s).

Check registration status from a phone console:

```text
/reginfo
```

## Build and deploy

```bash
cd voip
make build
```
Then deploy, the topology normally (terminal or VScode extension)

## Test

Open both phone consoles in separate terminals:

```bash
cd voip
make phone-crisp1
```

```bash
cd voip
make phone-crisp2
```

Both phones auto-register on startup. Verify with `/reginfo` before calling.

From `phone-crisp1`, place the call:

```text
/dial 1002
```

From `phone-crisp2`, answer:

```text
/accept
```

End the call from either side:

```text
/hangup
```

Detach from a phone console without stopping it: `Ctrl+C`.