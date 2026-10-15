#!/bin/bash
# soal15-uji-geto.sh - cek kesiapan + uji satu request lokal
# Jalankan di: geto
# Pemakaian  : bash /root/soal15-uji-geto.sh

ip -br a show eth0
ip route | grep default
nginx -v
for h in 192.236.4.5 192.236.4.6; do
    echo -n "$h : "
    curl -s -H "Host: jujutsu.K50.com" http://$h/api
    echo
done

echo "=== satu request lokal ==="
curl -s -i http://127.0.0.1/api
echo
echo "=== autostart ==="
cat /root/boot.d/nginx.sh
