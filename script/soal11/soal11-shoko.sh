#!/bin/bash
# soal11-serial-utahime.sh - tambah record gojo + naikkan serial SOA di Master
# Jalankan di: utahime
# Pemakaian  : bash /root/soal11-serial-utahime.sh

ZONE=/etc/bind/zones/db.jujutsu.K50.com

grep -q '^gojo' $ZONE || echo "gojo    IN      A       192.236.1.4" >> $ZONE

# Naikkan serial (nilai 10 digit pertama di zone file) sebanyak 1
OLD=$(grep -m1 -oE '[0-9]{10}' $ZONE)
NEW=$((OLD + 1))
sed -i "s/$OLD/$NEW/" $ZONE
echo "serial: $OLD -> $NEW"

named-checkzone jujutsu.K50.com $ZONE || exit 1
rndc reload jujutsu.K50.com
sleep 3
dig @127.0.0.1 jujutsu.K50.com SOA +short
