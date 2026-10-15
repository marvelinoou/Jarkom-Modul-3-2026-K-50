#!/bin/bash
# soal11-utahime.sh - DNS Master (BIND9) untuk zona jujutsu.K50.com
# Jalankan di: utahime
# Pemakaian  : bash /root/soal11-utahime.sh

mkdir -p /etc/bind/zones

cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.236.0.0/16; };
    dnssec-validation no;
};
EOF

cat > /etc/bind/named.conf.local << 'EOF'
zone "jujutsu.K50.com" {
    type primary;
    file "/etc/bind/zones/db.jujutsu.K50.com";
    notify yes;
    also-notify { 192.236.1.3; };
    allow-transfer { 192.236.1.3; };
};
EOF

cat > /etc/bind/zones/db.jujutsu.K50.com << 'EOF'
$TTL 3600
@       IN      SOA     utahime.jujutsu.K50.com. admin.jujutsu.K50.com. (
                        2026101401
                        3600
                        900
                        1209600
                        300 )

@       IN      NS      utahime.jujutsu.K50.com.
@       IN      NS      shoko.jujutsu.K50.com.

utahime IN      A       192.236.1.2
shoko   IN      A       192.236.1.3
EOF

chown -R root:bind /etc/bind/zones
chmod 755 /etc/bind/zones
chmod 644 /etc/bind/zones/db.jujutsu.K50.com

named-checkconf && echo "named.conf OK" || exit 1
named-checkzone jujutsu.K50.com /etc/bind/zones/db.jujutsu.K50.com || exit 1

# Jalankan BIND
service named restart
sleep 2
pgrep -a named
ss -ulnp | grep :53
ss -tlnp | grep :53
dig @127.0.0.1 jujutsu.K50.com SOA +short

# Autostart saat node restart (dibaca init.sh lewat boot.d)
mkdir -p /root/boot.d
echo 'service named start' > /root/boot.d/named.sh
cat /root/boot.d/named.sh
