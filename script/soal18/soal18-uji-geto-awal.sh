#!/bin/bash
# soal17-uji-log.sh - bukti dari log nginx (otomatis memilih log sesuai hostname)
# Jalankan di: gojo, geto, atau nanami
# Pemakaian  : bash /root/soal17-uji-log.sh

case "$(hostname)" in
    gojo) tail -n 6 /var/log/nginx/gojo-realip.log ;;
    geto) tail -n 6 /var/log/nginx/geto-realip.log ;;
    *)    tail -n 4 /var/log/nginx/api-realip.log ;;
esac
