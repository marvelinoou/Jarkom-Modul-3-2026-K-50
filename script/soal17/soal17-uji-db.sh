#!/bin/bash
# soal16-uji-yaga.sh - cek log request tercatat di database
# Jalankan di: yaga
# Pemakaian  : bash /root/soal16-uji-yaga.sh

mariadb -t -e "SELECT id, worker, client_ip, path FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 5;"
