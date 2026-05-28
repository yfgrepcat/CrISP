#!/bin/sh
set -e

mkdir -p /root/.baresip

# Detect the outbound IP (the address packets to the PBX would leave from).
# When running with --network host this is the host's physical interface IP.
SIP_LOCAL=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
: "${SIP_LOCAL:=0.0.0.0}"

cat > /root/.baresip/accounts << EOF
<sip:${SIP_USER}@${SIP_SERVER};transport=udp>;auth_pass=${SIP_PASS};regint=60;outbound="sip:${SIP_SERVER};transport=udp";
EOF

cat > /root/.baresip/config << EOF
module_path		/usr/lib/baresip/modules

module			account.so
module			g711.so
module			auloop.so
module			stdio.so
module			cons.so
module			menu.so

sip_listen		${SIP_LOCAL}:5060
audio_player		auloop
audio_source		auloop
audio_alert		auloop
EOF

exec "$@"
