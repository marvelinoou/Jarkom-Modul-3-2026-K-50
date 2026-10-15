cat > /root/setup-jichi.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-jichi.sh - Router utama: interface, IPv4 forwarding, NAT, DHCP Relay
# Pemakaian: bash /root/setup-jichi.sh          (setup penuh)
#            bash /root/setup-jichi.sh boot     (dipanggil init.sh saat boot)
MODE="${1:-full}"
PREFIX="192.236"

# 1. Interface
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

# WAN -> NAT1
auto eth0
iface eth0 inet dhcp

# Network 1 (DMZ)
auto eth1
iface eth1 inet static
    address $PREFIX.1.1
    netmask 255.255.255.0

# Network 2 (Divisi A)
auto eth2
iface eth2 inet static
    address $PREFIX.2.1
    netmask 255.255.255.0

# Network 3 (Divisi B)
auto eth3
iface eth3 inet static
    address $PREFIX.3.1
    netmask 255.255.255.0

# Network 4 (Data Center)
auto eth4
iface eth4 inet static
    address $PREFIX.4.1
    netmask 255.255.255.0
IFEOF

if [ "$MODE" = "full" ]; then
    for i in eth0 eth1 eth2 eth3 eth4; do
        ifdown --force $i 2>/dev/null
        ip addr flush dev $i 2>/dev/null
        ifup $i
    done
    sleep 3
fi

# 2. Forwarding + source NAT
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo "nameserver 192.168.122.1" > /etc/resolv.conf
iptables -t nat -C POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null ||
    iptables -t nat -A POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE

# 3. DHCP Relay -> tengen
if ! command -v dhcrelay >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-relay
fi
cat > /etc/default/isc-dhcp-relay <<RLEOF
SERVERS="$PREFIX.4.10"
INTERFACES=""
OPTIONS="-id eth2 -id eth3 -iu eth4"
RLEOF
pgrep -x dhcrelay >/dev/null || rm -f /var/run/dhcrelay.pid
service isc-dhcp-relay restart

# 4. Autostart saat boot (menggantikan init.sh lama)
if [ "$MODE" = "full" ]; then
cat > /root/init.sh <<'INITEOF'
#!/bin/bash
{
    bash /root/setup-jichi.sh boot
    for f in /root/boot.d/*.sh; do [ -f "$f" ] && bash "$f"; done
} > /root/init.log 2>&1
INITEOF
chmod +x /root/init.sh
mkdir -p /root/boot.d
fi

echo "===== HASIL ====="
ip -br a
iptables -t nat -S POSTROUTING
pgrep -a dhcrelay || echo "dhcrelay TIDAK jalan"
SETUP_EOF

bash /root/setup-jichi.sh