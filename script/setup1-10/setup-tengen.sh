cat > /root/setup-tengen.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-tengen.sh - DHCP Server (konfigurasi final soal 2-6)
# Pemakaian: bash /root/setup-tengen.sh          (setup penuh)
#            bash /root/setup-tengen.sh boot     (dipanggil init.sh saat boot)
MODE="${1:-full}"
PREFIX="192.236"

# MAC client. Nilai default = project Marvelino. Kalau MAC di projectmu beda,
# ubah di sini (client akan menampilkan MAC aslinya + perintah sed siap pakai).
MAC_ITADORI="02:42:05:9a:ab:00"
MAC_FUSHIGURO="02:42:c3:6e:65:00"
MAC_ZENIN="02:42:f6:49:44:00"
MAC_OKKOTSU="02:42:ef:c5:90:00"
MAC_INO="02:42:aa:da:e5:00"
MAC_KUSAKABE="02:42:5a:e2:39:00"
MAC_MIWA="02:42:35:f5:07:00"
MAC_KUGISAKI="02:42:7e:5f:c8:00"

# 1. Interface
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $PREFIX.4.10
    netmask 255.255.255.0
    gateway $PREFIX.4.1
    up echo nameserver 192.168.122.1 > /etc/resolv.conf
IFEOF

if [ "$MODE" = "full" ]; then
    ifdown --force eth0 2>/dev/null
    ip addr flush dev eth0 2>/dev/null
    ifup eth0
    sleep 2
fi
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# 2. isc-dhcp-server
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

option domain-name-servers $PREFIX.1.2, $PREFIX.1.3;
option domain-search "K50.com";

# Divisi A dipisah per MAC Address (1: = tipe hardware ethernet)
class "divA-pool1" { match hardware; }
subclass "divA-pool1" 1:$MAC_ITADORI;     # itadori
subclass "divA-pool1" 1:$MAC_FUSHIGURO;   # fushiguro

class "divA-pool2" { match hardware; }
subclass "divA-pool2" 1:$MAC_ZENIN;       # zenin
subclass "divA-pool2" 1:$MAC_OKKOTSU;     # okkotsu

# Divisi B dipisah per MAC Address
class "divB-short" { match hardware; }
subclass "divB-short" 1:$MAC_INO;         # ino
subclass "divB-short" 1:$MAC_KUSAKABE;    # kusakabe

class "divB-long" { match hardware; }
subclass "divB-long" 1:$MAC_MIWA;         # miwa

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

# Static lease kugisaki (di luar semua pool)
host kugisaki {
    hardware ethernet $MAC_KUGISAKI;
    fixed-address $PREFIX.3.99;
}
EOF

dhcpd -t -cf /etc/dhcp/dhcpd.conf || exit 1
pgrep -x dhcpd >/dev/null || rm -f /var/run/dhcpd.pid
service isc-dhcp-server restart

# 3. Autostart saat boot (menggantikan init.sh lama)
if [ "$MODE" = "full" ]; then
cat > /root/init.sh <<'INITEOF'
#!/bin/bash
{
    bash /root/setup-tengen.sh boot
    for f in /root/boot.d/*.sh; do [ -f "$f" ] && bash "$f"; done
} > /root/init.log 2>&1
INITEOF
chmod +x /root/init.sh
mkdir -p /root/boot.d
fi

echo "===== HASIL ====="
ip -br a show eth0
service isc-dhcp-server status
ss -ulnp | grep :67
SETUP_EOF

bash /root/setup-tengen.sh