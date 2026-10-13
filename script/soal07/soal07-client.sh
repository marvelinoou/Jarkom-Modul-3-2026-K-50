#!/bin/sh
# Soal 7 - client Divisi A/B: tampilkan konfigurasi jaringan hasil DHCP
echo "== $(hostname) =="
ip -4 -o addr show eth0 | awk '{print "ip/mask  :", $4, "| broadcast:", $6}'
ip link show eth0 | awk '/ether/{print "mac      :", $2}'
ip route | awk '/^default/{print "gateway  :", $3}'
cat /etc/resolv.conf
