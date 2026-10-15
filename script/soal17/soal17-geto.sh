#!/bin/bash
# soal16-uji-gojo-awal.sh - cek kesiapan jalur gojo ke backend (sebelum konfigurasi)
# Jalankan di: gojo
# Pemakaian  : bash /root/soal16-uji-gojo-awal.sh

ip -br a show eth0
ip route | grep default
nginx -v
echo "== maki";  curl -s -H "Host: jujutsu.K50.com" http://192.236.4.3/
echo "== panda"; curl -s -H "Host: jujutsu.K50.com" http://192.236.4.4/
echo "== geto";  curl -s -i http://192.236.4.2/api | egrep -i 'HTTP/|x-upstream|worker'
