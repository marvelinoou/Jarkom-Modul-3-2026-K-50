#!/bin/bash
# soal18-uji-geto.sh - uji langsung ke nanami dari geto (saat nanami mati harus gagal)
# Jalankan di: geto
# Pemakaian  : bash /root/soal18-uji-geto.sh

curl -s -o /dev/null -w "nanami langsung : %{http_code}\n" -H "Host: jujutsu.K50.com" http://192.236.4.5/api
