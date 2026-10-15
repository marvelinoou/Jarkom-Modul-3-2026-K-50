#!/bin/bash
# soal17-uji-db.sh - periksa client_ip yang tercatat di database
# Jalankan di: yaga, lalu inumaki (bukti replikasi)
# Pemakaian  : bash /root/soal17-uji-db.sh

mariadb -t -e "SELECT id, worker, client_ip, path, created_at FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 12;"
mariadb -t -e "SELECT client_ip, COUNT(*) AS total FROM db_shibuya_K50.request_logs GROUP BY client_ip;"
