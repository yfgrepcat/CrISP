# VoIP

Simple SIP call flow with one Asterisk PBX and 2 softphones.

```
phone-crisp1 (ext. 1001) ── CRISP client net ──┐
                                                ├── CRISP ── pbx (Asterisk :5060)
phone-crisp2 (ext. 1002) ── CRISP client net ──┘
```

## How it works

- `pbx` runs Asterisk with SIP users `1001` and `1002`
- `phone-crisp1` registers as `1001` to `voip.corentinpradier.com`
- `phone-crisp2` registers as `1002` to `voip.corentinpradier.com`

Topology service links:

- `pbx` on `120.0.40.5/24` in the CRISP DMZ
- `phone-crisp1` on `10.12.30.101/24` via `CRISP`
- `phone-crisp2` on `10.12.30.102/24` via `CRISP`

Credentials:

| Node | SIP ext | Password |
|---|---|---|
| pbx | - | - |
| phone-crisp1 | 1001 | secret1 |
| phone-crisp2 | 1002 | secret2 |

## Registration

Phones register automatically on startup (`regint=60`, re-registers every 60 s).

Check registration status from a phone console:

```text
/reginfo
```

Force re-registration:

```text
/register
```

Unregister:

```text
/unregister
```

## Build and deploy

```bash
cd voip
make build
cd ..

sudo containerlab destroy --topo topology.clab.yaml --cleanup
sudo containerlab deploy --topo topology.clab.yaml
```

## Smoke test

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

## Quick debug

```bash
docker logs clab-enterprise-ospf-bgp-pbx | tail -n 100
docker exec clab-enterprise-ospf-bgp-phone-crisp1 ip addr show eth1
docker exec clab-enterprise-ospf-bgp-phone-crisp2 ip addr show eth1
```

Verify DNS resolution from a phone:

```bash
docker exec clab-enterprise-ospf-bgp-phone-crisp1 getent hosts voip.corentinpradier.com
```

Note: audio quality is not the goal in this lab; the smoke test validates SIP registration and call signaling.
