#!/bin/sh
# soal12-client.sh - uji A, CNAME, PTR, forwarder dari client
# Jalankan di: itadori dan kusakabe
# Pemakaian  : sh /root/soal12-client.sh

dig @192.236.1.2 jujutsu.K50.com +short
dig @192.236.1.3 jujutsu.K50.com +short
dig www.jujutsu.K50.com +noall +answer
dig -x 192.236.1.4 +noall +answer
dig -x 192.236.1.4 | grep flags
ping -c 2 google.com
