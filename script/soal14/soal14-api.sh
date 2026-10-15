#!/bin/bash
# soal13-nanami-uji.sh - tes hak akses remote user shibuya dari node Network 4
# Jalankan di: nanami
# Pemakaian  : bash /root/soal13-nanami-uji.sh

mariadb -h 192.236.4.20 -u shibuya -pshibuya50 -e "SELECT worker, path FROM db_shibuya_K50.request_logs;"
mariadb -h 192.236.4.21 -u shibuya -pshibuya50 -e "SELECT worker, path FROM db_shibuya_K50.request_logs;"
