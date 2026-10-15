#!/bin/bash
# soal18-geto.sh - kirara sebagai backup + passive health check (max_fails=2 fail_timeout=5s)
# (konfigurasi soal 15 dan 17 dipertahankan)
# Jalankan di: geto
# Pemakaian  : bash /root/soal18-geto.sh
NANAMI="192.236.4.5"
TODO="192.236.4.6"
KIRARA="192.236.4.7"
GOJO="192.236.1.4"

rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/jujutsu-lb
cat > /etc/nginx/sites-available/jujutsu-lb <<'NGEOF'
upstream api_cluster {
    zone api_cluster 64k;
    server __NANAMI__ weight=3 max_fails=2 fail_timeout=5s;
    server __TODO__ weight=1 max_fails=2 fail_timeout=5s;
    server __KIRARA__ backup;
}

# Proxy terpercaya (soal 17)
geo $realip_remote_addr $from_trusted {
    default    0;
    __GOJO__   1;
}
map $from_trusted $xff_out {
    1        "$http_x_forwarded_for, $realip_remote_addr";
    default  $remote_addr;
}

log_format geto_realip 'peer=$realip_remote_addr client=$remote_addr xff="$xff_out" up=$upstream_addr ups=$upstream_status "$request" $status';

server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;
    access_log /var/log/nginx/geto-realip.log geto_realip;

    set_real_ip_from __GOJO__;
    real_ip_header X-Real-IP;
    real_ip_recursive off;

    location /api {
        proxy_pass http://api_cluster;
        proxy_connect_timeout 2s;
        proxy_next_upstream error timeout http_502 http_503 http_504;
        proxy_next_upstream_tries 3;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $xff_out;
        add_header X-Upstream $upstream_addr always;
        add_header X-Client-Seen $remote_addr always;
    }
}
NGEOF
sed -i "s/__NANAMI__/$NANAMI/g; s/__TODO__/$TODO/g; s/__KIRARA__/$KIRARA/g; s/__GOJO__/$GOJO/g" /etc/nginx/sites-available/jujutsu-lb
ln -sf /etc/nginx/sites-available/jujutsu-lb /etc/nginx/sites-enabled/jujutsu-lb

nginx -t || exit 1
service nginx restart

sleep 1
echo "===== HASIL geto ====="
nginx -t 2>&1 | tail -2
ss -tlnp | grep ':80 '
grep -A5 'upstream api_cluster' /etc/nginx/sites-available/jujutsu-lb
grep -nE 'proxy_next_upstream|proxy_connect_timeout' /etc/nginx/sites-available/jujutsu-lb
