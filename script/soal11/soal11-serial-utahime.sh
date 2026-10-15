#!/bin/bash
# soal11-serial-shoko.sh - cek Slave ikut sinkron setelah serial dinaikkan
# Jalankan di: shoko
# Pemakaian  : bash /root/soal11-serial-shoko.sh

sleep 3
dig @127.0.0.1 jujutsu.K50.com SOA +short
dig @127.0.0.1 gojo.jujutsu.K50.com +short
grep gojo /var/cache/bind/db.jujutsu.K50.com
