#!/bin/sh
# soal14-uji-client.sh - akses langsung dari klien ke worker (harus ditolak, 403)
# Jalankan di: itadori (Network 2) dan kusakabe (Network 3)
# Pemakaian  : sh /root/soal14-uji-client.sh

for h in 192.236.4.3 192.236.4.4; do
    echo -n "$h / -> "; curl -s -o /dev/null -w "%{http_code}\n" http://$h/
done
for h in 192.236.4.5 192.236.4.6 192.236.4.7; do
    echo -n "$h /api -> "; curl -s -o /dev/null -w "%{http_code}\n" http://$h/api
done
echo "--- Host header dipalsukan:"
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: jujutsu.K50.com" http://192.236.4.3/
echo "--- detail respons:"
curl -i http://192.236.4.5/api | head -3
