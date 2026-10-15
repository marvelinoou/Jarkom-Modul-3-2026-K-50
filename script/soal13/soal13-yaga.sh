#!/bin/bash
# soal13-inumaki.sh - MariaDB Slave: server-id, relay log, CHANGE MASTER TO, cek tereplikasi
# Jalankan di: inumaki (setelah soal13-yaga.sh selesai)
# Pemakaian  : bash /root/soal13-inumaki.sh

# 1. Konfigurasi Slave
cat > /etc/mysql/mariadb.conf.d/99-replication.cnf << 'EOF'
[mysqld]
bind-address = 0.0.0.0
skip-name-resolve
server-id = 2
relay_log = /var/lib/mysql/relay-bin
read_only = 1
EOF

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb restart
sleep 5
pgrep -a mariadbd
mariadb -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','read_only');"

# 2. Hubungkan ke Master (dilewati bila sudah terhubung, supaya event tidak diputar ulang)
if mariadb -e "SHOW SLAVE STATUS\G" | grep -q "Master_Host"; then
    echo ">> Slave sudah terhubung ke Master, CHANGE MASTER dilewati"
else
    mariadb -e "CHANGE MASTER TO MASTER_HOST='192.236.4.20', MASTER_USER='repl', MASTER_PASSWORD='replpass50', MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=4; START SLAVE;"
fi
sleep 5
mariadb -e "SHOW SLAVE STATUS\G" | egrep "Slave_IO_State|Master_Host|Master_Log_File|Read_Master_Log_Pos|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_IO_Error|Last_SQL_Error"

# 3. Cek DB, tabel, dan user sudah tereplikasi
mariadb -t -e "SHOW DATABASES LIKE 'db_shibuya%'; DESCRIBE db_shibuya_K50.request_logs;"
mariadb -t -e "SELECT user, host FROM mysql.user WHERE user IN ('shibuya','repl');"

# 4. Autostart saat node restart
mkdir -p /root/boot.d
cat > /root/boot.d/mariadb.sh << 'EOF'
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb start
EOF
cat /root/boot.d/mariadb.sh
