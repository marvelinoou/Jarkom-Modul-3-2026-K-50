#!/bin/bash
# soal15-uji-maki.sh - buktikan rasio 3:1 dari jaringan Data Center
# Jalankan di: maki
# Pemakaian  : bash /root/soal15-uji-maki.sh

echo "=== pola urutan (8 request) ==="
for i in $(seq 1 8); do curl -s http://192.236.4.2/api | grep -o '"worker":"[a-z]*"'; done

echo "=== hitung rasio (100 request) ==="
for i in $(seq 1 100); do curl -s http://192.236.4.2/api | grep -o '"worker":"[a-z]*"'; done | sort | uniq -c

echo "=== bukti lewat header X-Upstream (100 request) ==="
for i in $(seq 1 100); do curl -s -D - -o /dev/null http://192.236.4.2/api | grep -i '^x-upstream'; done | sort | uniq -c
