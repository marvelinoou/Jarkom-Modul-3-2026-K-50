#!/bin/bash
# soal16-uji-gojo.sh - uji lokal di gojo + cek autostart
# Jalankan di: gojo
# Pemakaian  : bash /root/soal16-uji-gojo.sh

echo "=== ROOT (/) ==="
curl -s -D - http://127.0.0.1/ | egrep -i 'HTTP/|x-gojo|Worker'
echo "=== /api ==="
curl -s -D - http://127.0.0.1/api | egrep -i 'HTTP/|x-gojo|x-upstream|worker'
echo "=== autostart ==="
cat /root/boot.d/nginx.sh
