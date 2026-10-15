#!/bin/bash
# soal11-shoko.sh - DNS Slave (BIND9) untuk zona jujutsu.K50.com
# Jalankan di: shoko (setelah utahime aktif)
# Pemakaian  : bash /root/soal11-shoko.sh

cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.236.0.0/16; };
    dnssec-validation no;
    masterfile-format text;
};
EOF

cat > /etc/bind/named.conf.local << 'EOF'
zone "jujutsu.K50.com" {
    type secondary;
    file "/var/cache/bind/db.jujutsu.K50.com";
    primaries { 192.236.1.2; };
    allow-transfer { none; };
};
EOF

chown -R bind:bind /var/cache/bind
named-checkconf && echo "named.conf OK" || exit 1

# Jalankan BIND dan cek hasil transfer zona
service named restart
sleep 5
pgrep -a named
ls -l /var/cache/bind/
dig @127.0.0.1 jujutsu.K50.com SOA +short
cat /var/cache/bind/db.jujutsu.K50.com

# Autostart saat node restart
mkdir -p /root/boot.d
echo 'service named start' > /root/boot.d/named.sh
cat /root/boot.d/named.sh
