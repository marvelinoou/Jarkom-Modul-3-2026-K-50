#!/bin/sh
# soal11-axfr.sh - uji pembatasan zone transfer (allow-transfer)
# Jalankan di: shoko   -> harus DIIZINKAN (zona tampil)
#              itadori -> harus DITOLAK   (Transfer failed / REFUSED)
# Pemakaian  : sh /root/soal11-axfr.sh

dig AXFR jujutsu.K50.com @192.236.1.2
