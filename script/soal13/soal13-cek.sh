#!/bin/bash
# soal12-shoko.sh - aktifkan forwarder di Slave, pastikan zona tersinkron
# Jalankan di: shoko
# Pemakaian  : bash /root/soal12-shoko.sh

cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.236.0.0/16; };
    forwarders { 192.168.122.1; };
    forward first;
    dnssec-validation no;
    masterfile-format text;
};
EOF

named-checkconf && echo "named.conf OK" || exit 1
service named restart
sleep 5
dig @127.0.0.1 jujutsu.K50.com SOA +short
dig @127.0.0.1 www.jujutsu.K50.com +noall +answer
dig @127.0.0.1 google.com +short
