#!/bin/bash
# Soal 10 - /root/init.sh pada jichi: autostart routing/NAT + DHCP Relay.
# debinet tidak memakai systemd; /root/init.sh dijalankan otomatis setiap node boot.
# (menggantikan init.sh versi soal 1)
{
    bash /root/soal01-jichi.sh
    bash /root/soal03-jichi.sh
} > /root/init.log 2>&1
