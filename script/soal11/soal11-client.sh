#!/bin/sh
# soal11-client-serial.sh - bukti sinkronisasi dari client
# Jalankan di: itadori
# Pemakaian  : sh /root/soal11-client-serial.sh

for s in 192.236.1.2 192.236.1.3; do
    echo -n "$s -> serial "
    dig +short SOA jujutsu.K50.com @$s | awk '{print $3}'
done
dig @192.236.1.2 gojo.jujutsu.K50.com +short
dig @192.236.1.3 gojo.jujutsu.K50.com +short
