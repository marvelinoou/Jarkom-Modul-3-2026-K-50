#!/bin/bash
# soal13-inumaki-uji.sh - cek data uji sudah muncul di Slave
# Jalankan di: inumaki
# Pemakaian  : bash /root/soal13-inumaki-uji.sh

sleep 2
mariadb -t -e "SELECT * FROM db_shibuya_K50.request_logs;"
mariadb -e "SHOW SLAVE STATUS\G" | egrep "Read_Master_Log_Pos|Exec_Master_Log_Pos|Seconds_Behind_Master"
