cat > /root/setup-client.sh << 'SETUP_EOF'
#!/bin/sh
# /root/setup-client.sh - Client Alpine: DHCP + paket uji (dig, curl, ab)
# Pemakaian: sh /root/setup-client.sh <nama>   (itadori fushiguro zenin okkotsu ino kusakabe miwa kugisaki)
NODE="${1:-$(hostname)}"

case "$NODE" in
    itadori)   VAR=MAC_ITADORI;   DEF=02:42:05:9a:ab:00 ;;
    fushiguro) VAR=MAC_FUSHIGURO; DEF=02:42:c3:6e:65:00 ;;
    zenin)     VAR=MAC_ZENIN;     DEF=02:42:f6:49:44:00 ;;
    okkotsu)   VAR=MAC_OKKOTSU;   DEF=02:42:ef:c5:90:00 ;;
    ino)       VAR=MAC_INO;       DEF=02:42:aa:da:e5:00 ;;
    kusakabe)  VAR=MAC_KUSAKABE;  DEF=02:42:5a:e2:39:00 ;;
    miwa)      VAR=MAC_MIWA;      DEF=02:42:35:f5:07:00 ;;
    kugisaki)  VAR=MAC_KUGISAKI;  DEF=02:42:7e:5f:c8:00 ;;
    *) echo "Nama client tidak dikenal: '$NODE'"; exit 1 ;;
esac

# 1. Interface DHCP (+ minta option 119 domain-search)
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    udhcpc_opts -O search
IFEOF

MAC="$(ip link show eth0 | awk '/ether/{print $2}')"
echo "===== MAC $NODE ====="
echo "MAC aktual : $MAC"
if [ "$MAC" = "$DEF" ]; then
    echo "Status     : COCOK dengan default di setup-tengen.sh"
else
    echo "Status     : BEDA dari default ($DEF)"
    echo "Jalankan di TENGEN:  sed -i 's/^$VAR=.*/$VAR=\"$MAC\"/' /root/setup-tengen.sh && bash /root/setup-tengen.sh"
fi

# 2. Ambil lease (gagal kalau jichi/tengen belum siap atau MAC belum terdaftar)
ifdown eth0 2>/dev/null; ifup eth0
echo "===== LEASE ====="
ip -4 -br a show eth0

# 3. Paket uji: pakai resolver NAT dulu (DNS DHCP baru hidup setelah soal 11)
echo "nameserver 192.168.122.1" > /etc/resolv.conf
apk update
apk add bind-tools curl apache2-utils

# 4. Kembalikan resolver dari DHCP
ifdown eth0 2>/dev/null; ifup eth0

echo "===== HASIL $NODE ====="
ip -4 -br a show eth0
ip route | grep default
cat /etc/resolv.conf
for c in dig curl ab; do command -v $c >/dev/null && echo "$c : terpasang" || echo "$c : BELUM"; done
SETUP_EOF