#!/bin/sh
# soal17-uji-client.sh - kirim request /api, client_ip harus IP klien (bukan IP gojo/geto)
# Jalankan di: itadori (Network 2) dan kusakabe (Network 3)
# Pemakaian  : sh /root/soal17-uji-client.sh

MYIP=$(ip -4 -br a show eth0 | awk '{print $3}' | cut -d/ -f1)
echo "IP $(hostname) : $MYIP"
for i in 1 2 3 4; do curl -s http://jujutsu.K50.com/api; echo; done
curl -s -D - -o /dev/null http://jujutsu.K50.com/api | egrep -i 'HTTP/|x-gojo|x-upstream|x-client-seen'
