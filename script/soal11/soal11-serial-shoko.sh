#!/bin/sh
# soal11-client.sh - query dig ke kedua DNS server (kondisi awal)
# Jalankan di: itadori
# Pemakaian  : sh /root/soal11-client.sh

dig @192.236.1.2 jujutsu.K50.com SOA +short
dig @192.236.1.3 jujutsu.K50.com SOA +short
dig @192.236.1.2 jujutsu.K50.com NS +short
dig @192.236.1.3 jujutsu.K50.com NS +short
dig @192.236.1.2 jujutsu.K50.com SOA | grep flags
dig @192.236.1.3 jujutsu.K50.com SOA | grep flags
