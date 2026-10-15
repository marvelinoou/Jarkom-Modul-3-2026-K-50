#!/bin/sh
# soal17-uji-spoof-client.sh - klien memalsukan header lewat gojo (harus diabaikan)
# Jalankan di: itadori
# Pemakaian  : sh /root/soal17-uji-spoof-client.sh

echo "IP $(hostname) : $(ip -4 -br a show eth0 | awk '{print $3}' | cut -d/ -f1)"
curl -s -H "X-Real-IP: 1.2.3.4" -H "X-Forwarded-For: 1.2.3.4" http://jujutsu.K50.com/api; echo
