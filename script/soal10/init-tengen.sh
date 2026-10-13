#!/bin/bash
# Soal 10 - /root/init.sh pada tengen: autostart DHCP Server.
# debinet tidak memakai systemd; /root/init.sh dijalankan otomatis setiap node boot.
bash /root/soal06-tengen.sh > /root/init.log 2>&1
