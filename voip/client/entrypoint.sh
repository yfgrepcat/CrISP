#!/bin/sh
mkdir -p /root/.baresip

# Wait for the service interface to be configured by containerlab exec commands
sleep 2
SIP_LOCAL=$(ip -4 addr show eth1 2>/dev/null | awk '/inet /{split($2,a,"/"); print a[1]; exit}')
if [ -z "$SIP_LOCAL" ]; then
	SIP_LOCAL=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{split($2,a,"/"); print a[1]; exit}')
fi
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
