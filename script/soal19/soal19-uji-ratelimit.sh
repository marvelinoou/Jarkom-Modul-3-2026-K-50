#!/bin/sh
# soal18-uji-client.sh - 20 request beruntun ke /api, rekap kode status + worker
# Jalankan di: itadori (dipakai di baseline, gangguan 1, gangguan 2, dan pemulihan)
# Pemakaian  : sh /root/soal18-uji-client.sh
#              sh /root/soal18-uji-client.sh tunggu   -> tunggu 6 detik dulu (setelah pemulihan)

[ "$1" = "tunggu" ] && sleep 6
for i in $(seq 1 20); do
    C=$(curl -s -o /tmp/r.json -w "%{http_code}" http://jujutsu.K50.com/api)
    echo "$C $(grep -o '"worker":"[a-z]*"' /tmp/r.json)"
done | sort | uniq -c
