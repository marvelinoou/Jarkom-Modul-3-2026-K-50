#!/bin/sh
# soal18-uji-detail.sh - satu request dengan header lengkap + 5 request cepat
# Jalankan di: itadori (saat nanami dan todo mati), lalu kusakabe untuk bukti Network 3
# Pemakaian  : sh /root/soal18-uji-detail.sh

curl -s -D - http://jujutsu.K50.com/api | egrep -i 'HTTP/|x-gojo|x-upstream|x-client-seen|status|worker'
echo
for i in 1 2 3 4 5; do curl -s -o /dev/null -w "%{http_code} " http://jujutsu.K50.com/api; done; echo
