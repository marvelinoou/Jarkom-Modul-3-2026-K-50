#!/bin/bash
# Soal 9 - jichi: simulasi gangguan DHCP Relay (disimpan di /root/soal09-jichi.sh)
# Pemakaian: bash /root/soal09-jichi.sh down   -> hentikan relay
#            bash /root/soal09-jichi.sh up     -> pulihkan relay
case "$1" in
    down) service isc-dhcp-relay stop ;;
    up)   pgrep -x dhcrelay >/dev/null || rm -f /var/run/dhcrelay.pid
          service isc-dhcp-relay start ;;
    *)    echo "pemakaian: $0 down|up"; exit 1 ;;
esac
service isc-dhcp-relay status
pgrep -a dhcrelay || echo "dhcrelay tidak berjalan"
