#!/bin/bash
# Soal 6 - tengen: static lease kugisaki, konfigurasi DHCP final (disimpan di /root/soal06-tengen.sh)

PREFIX="192.236"

if ! command -v dhcpd >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server
fi
sed -i 's/^INTERFACESv4=.*/INTERFACESv4="eth0"/' /etc/default/isc-dhcp-server

cat > /etc/dhcp/dhcpd.conf <<EOF
authoritative;
ddns-update-style none;

default-lease-time 600;
max-lease-time 7200;

# DHCP options untuk semua client (soal 5)
option domain-name-servers $PREFIX.1.2, $PREFIX.1.3;
option domain-search "K50.com";

# Divisi A dipisah per MAC Address (1: = tipe hardware ethernet)
class "divA-pool1" { match hardware; }
subclass "divA-pool1" 1:02:42:05:9a:ab:00;   # itadori
subclass "divA-pool1" 1:02:42:c3:6e:65:00;   # fushiguro

class "divA-pool2" { match hardware; }
subclass "divA-pool2" 1:02:42:f6:49:44:00;   # zenin
subclass "divA-pool2" 1:02:42:ef:c5:90:00;   # okkotsu

# Divisi B dipisah per MAC Address
class "divB-short" { match hardware; }
subclass "divB-short" 1:02:42:aa:da:e5:00;   # ino
subclass "divB-short" 1:02:42:5a:e2:39:00;   # kusakabe

class "divB-long" { match hardware; }
subclass "divB-long" 1:02:42:35:f5:07:00;    # miwa (node "ralwa" di project)

# Network 4 (Data Center) - subnet lokal tengen, tanpa pool dinamis
subnet $PREFIX.4.0 netmask 255.255.255.0 {
}

# Network 2 (Divisi A) - .2.36 s/d .2.69 tidak dialokasikan
subnet $PREFIX.2.0 netmask 255.255.255.0 {
    option routers $PREFIX.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address $PREFIX.2.255;

    pool {
        allow members of "divA-pool1";
        range $PREFIX.2.10 $PREFIX.2.35;
    }
    pool {
        allow members of "divA-pool2";
        range $PREFIX.2.70 $PREFIX.2.95;
    }
}

# Network 3 (Divisi B)
subnet $PREFIX.3.0 netmask 255.255.255.0 {
    option routers $PREFIX.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address $PREFIX.3.255;

    # short lease 30 menit
    pool {
        allow members of "divB-short";
        range $PREFIX.3.10 $PREFIX.3.89;
        default-lease-time 1800;
        max-lease-time 1800;
    }
    # long lease 12 jam
    pool {
        allow members of "divB-long";
        range $PREFIX.3.100 $PREFIX.3.199;
        default-lease-time 43200;
        max-lease-time 43200;
    }
}

# Static lease kugisaki (di luar pool .3.10-.3.89 dan .3.100-.3.199)
host kugisaki {
    hardware ethernet 02:42:7e:5f:c8:00;
    fixed-address $PREFIX.3.99;
}
EOF

# Validasi dulu, baru restart
dhcpd -t -cf /etc/dhcp/dhcpd.conf || exit 1
pgrep -x dhcpd >/dev/null || rm -f /var/run/dhcpd.pid
service isc-dhcp-server restart
service isc-dhcp-server status
