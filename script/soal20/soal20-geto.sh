#!/bin/bash
# soal18-uji-geto-awal.sh - cek kesiapan kirara (semua worker API harus menjawab)
# Jalankan di: geto
# Pemakaian  : bash /root/soal18-uji-geto-awal.sh

for h in 192.236.4.5 192.236.4.6 192.236.4.7; do
    echo -n "$h : "
    curl -s -H "Host: jujutsu.K50.com" http://$h/api
    echo
done
