#!/bin/bash
# Soal 1 - jichi: IPv4 forwarding + source NAT (disimpan di /root/soal01-jichi.sh)
# IP eth0-eth4 diatur lewat /etc/network/interfaces.

PREFIX="192.236"

# IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# Source NAT: Network 1-4 keluar lewat eth0 (NAT1)
iptables -t nat -C POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null ||
    iptables -t nat -A POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE

# Resolver untuk persiapan awal
echo "nameserver 192.168.122.1" > /etc/resolv.conf
