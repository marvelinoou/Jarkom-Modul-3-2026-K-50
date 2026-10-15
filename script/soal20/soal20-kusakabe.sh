#!/bin/bash
# soal18-uji-log.sh - bukti dari log geto, kirara, dan database (otomatis sesuai hostname)
# Jalankan di: geto, kirara, atau yaga
# Pemakaian  : bash /root/soal18-uji-log.sh

case "$(hostname)" in
    geto)
        grep -c 'ups=' /var/log/nginx/geto-realip.log
        tail -n 6 /var/log/nginx/geto-realip.log ;;
    kirara)
        tail -n 4 /var/log/nginx/api-realip.log ;;
    yaga)
        mariadb -t -e "SELECT id, worker, client_ip, path FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 10;"
        mariadb -t -e "SELECT worker, client_ip, COUNT(*) AS total FROM db_shibuya_K50.request_logs GROUP BY worker, client_ip;" ;;
    *)  echo "jalankan di geto, kirara, atau yaga"; exit 1 ;;
esac
