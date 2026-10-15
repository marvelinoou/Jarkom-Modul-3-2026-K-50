#!/bin/bash
# soal14-uji-inumaki.sh - log di database sudah tereplikasi ke Slave
# Jalankan di: inumaki
# Pemakaian  : bash /root/soal14-uji-inumaki.sh

mariadb -t -e "SELECT id, worker, client_ip, path FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 5;"
