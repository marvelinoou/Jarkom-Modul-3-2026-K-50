cat > /root/setup-node.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-node.sh - Node Debian (non-router, non-DHCP): interface + paket soal 11-20
# Pemakaian: bash /root/setup-node.sh <nama>          (setup penuh)
#            bash /root/setup-node.sh <nama> boot     (dipanggil init.sh saat boot)
NODE="${1:-$(hostname)}"
MODE="${2:-full}"

case "$NODE" in
    utahime) IP=192.236.1.2;  GW=192.236.1.1; PKGS="bind9 dnsutils curl" ;;
    shoko)   IP=192.236.1.3;  GW=192.236.1.1; PKGS="bind9 dnsutils curl" ;;
    gojo)    IP=192.236.1.4;  GW=192.236.1.1; PKGS="nginx curl" ;;
    geto)    IP=192.236.4.2;  GW=192.236.4.1; PKGS="nginx curl" ;;
    maki)    IP=192.236.4.3;  GW=192.236.4.1; PKGS="nginx php-fpm curl" ;;
    panda)   IP=192.236.4.4;  GW=192.236.4.1; PKGS="nginx php-fpm curl" ;;
    nanami)  IP=192.236.4.5;  GW=192.236.4.1; PKGS="nginx php-fpm php-mysql mariadb-client curl" ;;
    todo)    IP=192.236.4.6;  GW=192.236.4.1; PKGS="nginx php-fpm php-mysql mariadb-client curl" ;;
    kirara)  IP=192.236.4.7;  GW=192.236.4.1; PKGS="nginx php-fpm php-mysql mariadb-client curl" ;;
    yaga)    IP=192.236.4.20; GW=192.236.4.1; PKGS="mariadb-server curl" ;;
    inumaki) IP=192.236.4.21; GW=192.236.4.1; PKGS="mariadb-server curl" ;;
    *) echo "Nama node tidak dikenal: '$NODE'"; echo "Pakai: bash $0 <utahime|shoko|gojo|geto|maki|panda|nanami|todo|kirara|yaga|inumaki>"; exit 1 ;;
esac

# 1. Interface
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $IP
    netmask 255.255.255.0
    gateway $GW
    up echo nameserver 192.168.122.1 > /etc/resolv.conf
IFEOF

if [ "$MODE" = "full" ]; then
    ifdown --force eth0 2>/dev/null
    ip addr flush dev eth0 2>/dev/null
    ifup eth0
    sleep 2
fi
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# 2. Paket (hanya download kalau ada yang belum terpasang)
NEED=""
for p in $PKGS; do dpkg -s "$p" >/dev/null 2>&1 || NEED="$NEED $p"; done
if [ -n "$NEED" ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y $NEED
fi

# 3. Autostart saat boot
if [ "$MODE" = "full" ]; then
cat > /root/init.sh <<INITEOF
#!/bin/bash
{
    bash /root/setup-node.sh $NODE boot
    for f in /root/boot.d/*.sh; do [ -f "\$f" ] && bash "\$f"; done
} > /root/init.log 2>&1
INITEOF
chmod +x /root/init.sh
mkdir -p /root/boot.d
fi

# 4. Ringkasan
echo "===== HASIL $NODE ====="
ip -br a show eth0
ip route | grep default
ping -c 1 -W 2 $GW >/dev/null && echo "gateway $GW : OK" || echo "gateway $GW : GAGAL"
ping -c 1 -W 2 8.8.8.8 >/dev/null && echo "internet 8.8.8.8 : OK" || echo "internet 8.8.8.8 : GAGAL"
ping -c 1 -W 2 google.com >/dev/null && echo "DNS google.com : OK" || echo "DNS google.com : GAGAL"
for p in $PKGS; do dpkg -s "$p" >/dev/null 2>&1 && echo "paket $p : terpasang" || echo "paket $p : BELUM"; done
SETUP_EOF