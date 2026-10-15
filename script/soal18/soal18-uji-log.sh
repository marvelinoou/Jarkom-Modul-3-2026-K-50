#!/bin/bash
# soal17-uji-spoof-maki.sh - node tak terpercaya menembak geto langsung dengan header palsu
# Jalankan di: maki
# Pemakaian  : bash /root/soal17-uji-spoof-maki.sh

curl -s -H "X-Real-IP: 1.2.3.4" -H "X-Forwarded-For: 1.2.3.4" http://192.236.4.2/api; echo
