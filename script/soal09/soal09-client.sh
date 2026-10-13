#!/bin/sh
# Soal 9 - client (mis. ino): paksa minta lease baru
# Dipakai dua kali: saat relay mati (gagal) dan setelah relay pulih (berhasil).
ifdown eth0 2>/dev/null          # lepas lease lama
ip addr flush dev eth0
ip link set eth0 up              # ifdown mematikan link, nyalakan lagi sebelum udhcpc
if udhcpc -i eth0 -n -q -t 3 -T 2 -O search; then
    ifup eth0                    # kembali ke mode normal (udhcpc jalan di background)
else
    echo ">> GAGAL: tidak ada DHCPOFFER (relay mati?)"
fi
ip -br a show eth0
ip route
