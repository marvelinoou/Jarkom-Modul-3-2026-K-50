#!/bin/bash
# soal13-yaga-uji.sh - insert data uji di Master
# Jalankan di: yaga
# Pemakaian  : bash /root/soal13-yaga-uji.sh

mariadb -e "INSERT INTO db_shibuya_K50.request_logs (worker, client_ip, path) VALUES ('uji-replikasi-1','192.236.2.10','/tes1'),('uji-replikasi-2','192.236.3.10','/tes2');"
mariadb -t -e "SELECT * FROM db_shibuya_K50.request_logs;"
mariadb -t -e "SHOW MASTER STATUS;"
