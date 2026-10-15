#!/bin/bash
# soal14-uji-gojo.sh - akses lewat jalur proxy ke worker frontend (harus berhasil)
# Jalankan di: gojo
# Pemakaian  : bash /root/soal14-uji-gojo.sh

for h in 192.236.4.3 192.236.4.4; do
    echo "== $h"
    curl -s -H "Host: jujutsu.K50.com" http://$h/
done
