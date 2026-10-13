#!/bin/bash
# Soal 3 - jichi: DHCP Relay menuju tengen (disimpan di /root/soal03-jichi.sh)

PREFIX="192.236"

if ! command -v dhcrelay >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-relay
fi

# eth2/eth3 = sisi client (downstream), eth4 = sisi tengen (upstream).
# Tanpa eth4, balasan dari tengen dibuang oleh relay.
cat > /etc/default/isc-dhcp-relay <<EOF
SERVERS="$PREFIX.4.10"
INTERFACES=""
OPTIONS="-id eth2 -id eth3 -iu eth4"
EOF

pgrep -x dhcrelay >/dev/null || rm -f /var/run/dhcrelay.pid
service isc-dhcp-relay restart
service isc-dhcp-relay status
