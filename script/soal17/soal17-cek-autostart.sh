#!/bin/sh
# soal16-uji-client.sh - uji path-based routing dari client Divisi A / B
# Jalankan di: itadori dan kusakabe
# Pemakaian  : sh /root/soal16-uji-client.sh

echo "=== resolusi DNS ==="
cat /etc/resolv.conf
dig +short jujutsu.K50.com
dig +short www.jujutsu.K50.com

echo "=== Round Robin root (/), 6 request ==="
for i in $(seq 1 6); do curl -s http://jujutsu.K50.com/ | grep Worker; done

echo "=== hitung rasio root (100 request) ==="
for i in $(seq 1 100); do curl -s http://jujutsu.K50.com/ | grep -o 'Worker: [a-z]*'; done | sort | uniq -c

echo "=== /api lewat gojo (header) ==="
curl -s -D - http://jujutsu.K50.com/api | egrep -i 'HTTP/|x-gojo|x-upstream|worker'

echo "=== distribusi /api (40 request, diteruskan ke geto jadi 3:1) ==="
for i in $(seq 1 40); do curl -s http://jujutsu.K50.com/api | grep -o '"worker":"[a-z]*"'; done | sort | uniq -c

echo "=== domain www ==="
echo "--- www root:"
curl -s http://www.jujutsu.K50.com/ | grep Worker
echo "--- www api:"
curl -s http://www.jujutsu.K50.com/api | grep -o '"worker":"[a-z]*"'

echo "=== gojo adalah gerbang tunggal ==="
echo -n "via gojo        -> / : "; curl -s -o /dev/null -w "%{http_code}\n" http://jujutsu.K50.com/
echo -n "langsung maki   -> / : "; curl -s -o /dev/null -w "%{http_code}\n" http://192.236.4.3/
echo -n "langsung nanami -> /api : "; curl -s -o /dev/null -w "%{http_code}\n" http://192.236.4.5/api
