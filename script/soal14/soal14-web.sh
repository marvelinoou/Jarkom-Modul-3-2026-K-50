#!/bin/bash
# soal14-uji-geto.sh - akses dari geto ke worker API (harus berhasil)
# Jalankan di: geto
# Pemakaian  : bash /root/soal14-uji-geto.sh

for h in 192.236.4.5 192.236.4.6 192.236.4.7; do
    echo "== $h"
    curl -s -H "Host: jujutsu.K50.com" http://$h/api
    echo
done
