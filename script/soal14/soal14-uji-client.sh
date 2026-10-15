#!/bin/bash
# soal13-yaga.sh - MariaDB Master: binlog, user replikasi, database, tabel, user remote Network 4
# Jalankan di: yaga
# Pemakaian  : bash /root/soal13-yaga.sh

# 1. Konfigurasi Master (server-id + binary log)
cat > /etc/mysql/mariadb.conf.d/99-replication.cnf << 'EOF'
[mysqld]
bind-address = 0.0.0.0
skip-name-resolve
server-id = 1
log_bin = /var/lib/mysql/mysql-bin
EOF

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb restart
sleep 5
pgrep -a mariadbd
ss -tlnp | grep 3306
mariadb -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','log_bin');"

# 2. User replikasi (khusus inumaki)
mariadb -e "CREATE USER IF NOT EXISTS 'repl'@'192.236.4.21' IDENTIFIED BY 'replpass50'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'192.236.4.21'; FLUSH PRIVILEGES;"
mariadb -t -e "SELECT user, host FROM mysql.user WHERE user='repl';"

# 3. Database, tabel, dan user remote seluruh Network 4
mariadb << 'EOF'
CREATE DATABASE IF NOT EXISTS db_shibuya_K50;
USE db_shibuya_K50;
CREATE TABLE IF NOT EXISTS request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    worker VARCHAR(50) NOT NULL,
    client_ip VARCHAR(45) DEFAULT NULL,
    path VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE USER IF NOT EXISTS 'shibuya'@'192.236.4.%' IDENTIFIED BY 'shibuya50';
GRANT ALL PRIVILEGES ON db_shibuya_K50.* TO 'shibuya'@'192.236.4.%';
FLUSH PRIVILEGES;
EOF

mariadb -t -e "SHOW DATABASES LIKE 'db_shibuya%'; DESCRIBE db_shibuya_K50.request_logs;"
mariadb -t -e "SELECT user, host FROM mysql.user WHERE user IN ('shibuya','repl');"

# 4. Cek file binlog
mariadb -t -e "SHOW BINARY LOGS; SHOW MASTER STATUS;"

# 5. Autostart saat node restart (/run hilang tiap boot)
mkdir -p /root/boot.d
cat > /root/boot.d/mariadb.sh << 'EOF'
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb start
EOF
cat /root/boot.d/mariadb.sh
