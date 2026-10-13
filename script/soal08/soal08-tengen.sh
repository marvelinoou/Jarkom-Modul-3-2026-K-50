#!/bin/bash
# Soal 8 - tengen: capture DORA milik itadori (02:42:05:9a:ab:00) yang datang lewat relay jichi
# Urutan: (1) itadori: ifdown eth0   (2) tengen: bash /root/soal08-tengen.sh   (3) itadori: ifup eth0
# ifdown dilakukan lebih dulu supaya paket DHCPRELEASE tidak ikut terhitung dalam 4 paket.
# Filter chaddr (udp[36:6]) supaya renew client lain tidak ikut tertangkap.
timeout 60 tcpdump -i eth0 -n -vvv -c 4 \
    'udp port 67 and udp[36:4] = 0x0242059a and udp[40:2] = 0xab00' 2>&1 | tee /root/soal08-dora.txt

echo "===== RINGKASAN ====="
grep -E "DHCP-Message|Your-IP|Gateway-IP|Server-ID|Lease-Time" /root/soal08-dora.txt
