#!/bin/bash
# soal13-cek.sh - cek kesiapan node database
# Jalankan di: yaga dan inumaki
# Pemakaian  : bash /root/soal13-cek.sh

mariadbd --version
ip -br a show eth0
ls /var/lib/mysql | head -5
