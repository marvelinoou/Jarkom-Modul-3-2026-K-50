#!/bin/bash
# soal14-uji-yaga.sh - bukti worker hanya menerima gojo/geto + cek log tercatat di database
# Jalankan di: yaga
# Pemakaian  : bash /root/soal14-uji-yaga.sh

# Node Network 4 selain geto/gojo harus ditolak
curl -s -o /dev/null -w "yaga -> nanami /api : %{http_code}\n" http://192.236.4.5/api
curl -s -o /dev/null -w "yaga -> maki /      : %{http_code}\n" http://192.236.4.3/

# Log tercatat di database
mariadb -t -e "SELECT id, worker, client_ip, path, created_at FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 5;"
mariadb -t -e "SELECT worker, COUNT(*) AS total FROM db_shibuya_K50.request_logs GROUP BY worker;"
