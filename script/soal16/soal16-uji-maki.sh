#!/bin/bash
# soal15-uji-yaga.sh - konfirmasi rasio dari sisi database (bukti independen)
# Jalankan di: yaga
# Pemakaian  : bash /root/soal15-uji-yaga.sh

mariadb -t -e "SELECT worker, COUNT(*) AS total FROM (SELECT worker FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 100) t GROUP BY worker;"
