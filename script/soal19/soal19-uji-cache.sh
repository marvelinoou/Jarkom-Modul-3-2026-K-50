#!/bin/bash
# soal18-gangguan.sh - simulasi gangguan: matikan / nyalakan nginx worker API
# Jalankan di: nanami dan todo
# Pemakaian  : bash /root/soal18-gangguan.sh stop    -> matikan nginx
#              bash /root/soal18-gangguan.sh start   -> pulihkan nginx
case "$1" in
    stop)  service nginx stop
           pgrep -a nginx || echo "nginx $(hostname) mati" ;;
    start) service nginx start
           sleep 1
           pgrep -a nginx | head -2 ;;
    *)     echo "pemakaian: $0 stop|start"; exit 1 ;;
esac
