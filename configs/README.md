## Arista vEOS image

`P4` runs as Arista vEOS and needs the `vrnetlab/arista_veos:4.31.0F` image present locally. The topology pins `image-pull-policy: Never`, so containerlab never tries to pull it — you must load or build it first.

Load the prebuilt image from the archive shipped with the repo:

```bash
docker load -i arista_veos_4.31.0F.tar.gz
docker images | grep arista_veos      # expect: vrnetlab/arista_veos   4.31.0F
```

Alternatively build it yourself from an EOS image with `./scripts/build-veos-image.sh`. If you use a different tag, override it at deploy time with `VEOS_IMAGE=<repo:tag>`.

## Arista P4 breakout trunk

`P4` runs as Arista vEOS using `configs/P4.eos.cfg`. The default local image tag is `vrnetlab/arista_veos:4.31.0F`; override it during deployment with `VEOS_IMAGE` if needed.

The physical breakout trunk uses Linux VLAN subinterfaces on one host NIC:

| VLAN | Linux interface | Host bridge | Containerlab endpoint |
| --- | --- | --- | --- |
| `104` | `clab104` | `breakout-trunk` | `P4:Ethernet4` |
| `121` | `clab121` | `br-vlan121` | `PE-nomad:e1-3` |
| `122` | `clab122` | `br-vlan122` | `PE-site:e1-5` |

Run:

```bash
TRUNK_IFACE=<your-host-nic> sudo -E ./scripts/connect-breakout-trunk.sh
```

### Configuration Options & Environment Variables

The setup scripts ([create-host-bridges.sh](file:///home/tructruc00/cours/S8/projet-reseau/enterprise-network/scripts/create-host-bridges.sh) and [connect-breakout-trunk.sh](file:///home/tructruc00/cours/S8/projet-reseau/enterprise-network/scripts/connect-breakout-trunk.sh)) support several environment variables to customize physical network attachment:

| Environment Variable | Description | Default / Example |
| --- | --- | --- |
| `TRUNK_IFACE` | Host interface connected to the physical switch trunk (VLAN-backed breakout mode). | (Required for VLAN mode) |
| `RAW_TRUNK_IFACE` | Host interface to bridge directly to the raw trunk. | (Optional) |
| `P4_TRANSPORT_IFACE` | Host interface specifically for P4 transport. | Defaults to `$TRUNK_IFACE` |
| `P4_TRANSPORT_VLAN` | VLAN ID used for P4 transport. | `104` |
| `VLAN_IFACE_PREFIX` | Prefix for the created host VLAN subinterfaces. | `clab` |

### Test from the Arista P4 router

`P4` is reached over its vrnetlab serial console (it has no management IP). Open it with telnet:

```bash
docker exec -it clab-enterprise-ospf-bgp-P4 telnet localhost 5000
```

Log in as the RADIUS user `alice` / `alice123` — you land directly at privilege level 15 (`P4#`):

```text
P4#show privilege                            ! -> Current privilege level is 15
P4#test aaa group radius alice alice123      ! -> "User was successfully authenticated."
P4#test aaa group radius bob  wrongpw        ! -> "Authentication failed"
```

> Note: with `aaa authentication login default group radius local`, EOS only falls back to the local `admin` account when RADIUS is **unreachable** — a RADIUS *reject* is final. Use `alice`/`bob` (privilege 15) as the day-to-day admins; local `admin` is the break-glass login for when the RADIUS server is down. The `aaa authorization serial-console` line in `configs/P4.eos.cfg` is what makes the RADIUS-returned privilege level apply to console logins (EOS disables console authorization by default).
