#!/bin/sh
mkdir -p /root/.baresip

cat > /root/.baresip/accounts << EOF
<sip:${SIP_USER}@${SIP_SERVER};transport=udp>;auth_pass=${SIP_PASS};regint=60;
EOF

cat > /root/.baresip/config << 'EOF'
module_path		/usr/lib/baresip/modules

module			account.so
module			g711.so
module			auloop.so
module			stdio.so
module			cons.so
module			menu.so

sip_listen		0.0.0.0:5060
audio_player		auloop
audio_source		auloop
audio_alert		auloop
EOF

exec "$@"
