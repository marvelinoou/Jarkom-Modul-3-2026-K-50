#!/bin/bash
# soal17-geto.sh - LB meneruskan IP klien, hanya percaya gojo
# Jalankan di: geto
# Pemakaian  : bash /root/soal17-geto.sh
NANAMI="192.236.4.5"
TODO="192.236.4.6"
GOJO="192.236.1.4"

rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/jujutsu-lb
cat > /etc/nginx/sites-available/jujutsu-lb <<'NGEOF'
upstream api_cluster {
    zone api_cluster 64k;
    server __NANAMI__ weight=3;
    server __TODO__ weight=1;
}

# Daftar proxy terpercaya, dinilai dari alamat peer asli koneksi
geo $realip_remote_addr $from_trusted {
    default    0;
    __GOJO__   1;
}

# Rantai X-Forwarded-For yang dikirim ke worker:
#  - dari gojo     : rantai dari gojo + IP gojo
#  - dari selain gojo : dibuang, diganti IP peer (anti-spoof)
map $from_trusted $xff_out {
    1        "$http_x_forwarded_for, $realip_remote_addr";
    default  $remote_addr;
}

log_format geto_realip 'peer=$realip_remote_addr client=$remote_addr xff="$xff_out" up=$upstream_addr "$request" $status';

server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;
    access_log /var/log/nginx/geto-realip.log geto_realip;

    # IP klien dari X-Real-IP hanya dipercaya bila koneksi datang dari gojo
    set_real_ip_from __GOJO__;
    real_ip_header X-Real-IP;
    real_ip_recursive off;

    location /api {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $xff_out;
        add_header X-Upstream $upstream_addr always;
        add_header X-Client-Seen $remote_addr always;
    }
}
NGEOF
sed -i "s/__NANAMI__/$NANAMI/g; s/__TODO__/$TODO/g; s/__GOJO__/$GOJO/g" /etc/nginx/sites-available/jujutsu-lb
ln -sf /etc/nginx/sites-available/jujutsu-lb /etc/nginx/sites-enabled/jujutsu-lb

nginx -t || exit 1
service nginx restart

sleep 1
echo "===== HASIL geto ====="
nginx -t 2>&1 | tail -2
ss -tlnp | grep ':80 '
grep -nE 'set_real_ip_from|real_ip_header|weight=' /etc/nginx/sites-available/jujutsu-lb
