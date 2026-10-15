#!/bin/bash
# soal12-utahime.sh - A record utama, CNAME www, reverse zone (PTR), DNS forwarder
# Jalankan di: utahime
# Pemakaian  : bash /root/soal12-utahime.sh

# 1. Zona utama: jujutsu.K50.com -> gojo, www -> CNAME
cat > /etc/bind/zones/db.jujutsu.K50.com << 'EOF'
$TTL 3600
@       IN      SOA     utahime.jujutsu.K50.com. admin.jujutsu.K50.com. (
                        2026101403
                        3600
                        900
                        1209600
                        300 )

@       IN      NS      utahime.jujutsu.K50.com.
@       IN      NS      shoko.jujutsu.K50.com.

@       IN      A       192.236.1.4
www     IN      CNAME   jujutsu.K50.com.

utahime IN      A       192.236.1.2
shoko   IN      A       192.236.1.3
gojo    IN      A       192.236.1.4
EOF

named-checkzone jujutsu.K50.com /etc/bind/zones/db.jujutsu.K50.com || exit 1

# 2. Reverse zone (PTR) Network 1
cat > /etc/bind/named.conf.local << 'EOF'
zone "jujutsu.K50.com" {
    type primary;
    file "/etc/bind/zones/db.jujutsu.K50.com";
    notify yes;
    also-notify { 192.236.1.3; };
    allow-transfer { 192.236.1.3; };
};

zone "1.236.192.in-addr.arpa" {
    type primary;
    file "/etc/bind/zones/db.1.236.192";
};
EOF

cat > /etc/bind/zones/db.1.236.192 << 'EOF'
$TTL 3600
@       IN      SOA     utahime.jujutsu.K50.com. admin.jujutsu.K50.com. (
                        2026101401
                        3600
                        900
                        1209600
                        300 )

@       IN      NS      utahime.jujutsu.K50.com.

4       IN      PTR     jujutsu.K50.com.
EOF

chown -R root:bind /etc/bind/zones
chmod 644 /etc/bind/zones/db.1.236.192

named-checkzone 1.236.192.in-addr.arpa /etc/bind/zones/db.1.236.192 || exit 1

# 3. DNS Forwarder ke gateway internet
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
};
EOF

named-checkconf && echo "named.conf OK" || exit 1

# 4. Restart dan cek lokal
service named restart
sleep 3
dig @127.0.0.1 jujutsu.K50.com SOA +short
dig @127.0.0.1 jujutsu.K50.com +short
dig @127.0.0.1 www.jujutsu.K50.com +noall +answer
dig @127.0.0.1 -x 192.236.1.4 +noall +answer
dig @127.0.0.1 google.com +short
