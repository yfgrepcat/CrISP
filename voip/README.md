# VoIP

Simple SIP call flow with one Asterisk PBX and 2 softphones.

```
phone-site  (ext. 1001) ── PE-site  ──┐
                                       ├── P4 ── pbx (Asterisk :5060)
phone-nomad (ext. 1002) ── PE-nomad ──┘
```

## How it works

- `pbx` runs Asterisk with SIP users `1001` and `1002`
- `phone-site` registers as `1001` to `120.0.35.1`
- `phone-nomad` registers as `1002` to `120.0.35.1`

Topology service links:

- `pbx` on `120.0.35.1/31` (toward `P4`)
- `phone-site` on `120.0.35.3/31` via `PE-site`
- `phone-nomad` on `120.0.35.5/31` via `PE-nomad`

Credentials:

| Node | SIP ext | Password |
|---|---|---|
| pbx | - | - |
| phone-site | 1001 | secret1 |
| phone-nomad | 1002 | secret2 |

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
make phone-site
```

```bash
cd voip
make phone-nomad
```

From `phone-site`, place the call:

```text
/dial 1002
```

From `phone-nomad`, answer:

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
docker exec clab-enterprise-ospf-bgp-phone-site ip addr show eth1
docker exec clab-enterprise-ospf-bgp-phone-nomad ip addr show eth1
```

Note: audio quality is not the goal in this lab; the smoke test validates SIP registration and call signaling.
