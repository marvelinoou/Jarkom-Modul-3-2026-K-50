#!/bin/bash
# soal17-gojo.sh - gojo mengirim X-Real-IP dan X-Forwarded-For
# Jalankan di: gojo
# Pemakaian  : bash /root/soal17-gojo.sh
MAKI="192.236.4.3"
PANDA="192.236.4.4"
GETO="192.236.4.2"

rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/jujutsu-proxy
cat > /etc/nginx/sites-available/jujutsu-proxy <<'NGEOF'
upstream frontend_cluster {
    zone frontend_cluster 64k;
    server __MAKI__;
    server __PANDA__;
}

upstream geto_lb {
    server __GETO__;
}

log_format gojo_realip '$remote_addr xff="$http_x_forwarded_for" up=$upstream_addr "$request" $status';

server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;
    access_log /var/log/nginx/gojo-realip.log gojo_realip;

    location / {
        proxy_pass http://frontend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        add_header X-Gojo-Upstream $upstream_addr always;
    }

    location /api {
        proxy_pass http://geto_lb;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        add_header X-Gojo-Upstream $upstream_addr always;
    }
}
NGEOF
sed -i "s/__MAKI__/$MAKI/g; s/__PANDA__/$PANDA/g; s/__GETO__/$GETO/g" /etc/nginx/sites-available/jujutsu-proxy
ln -sf /etc/nginx/sites-available/jujutsu-proxy /etc/nginx/sites-enabled/jujutsu-proxy

nginx -t || exit 1
service nginx restart

sleep 1
echo "===== HASIL gojo ====="
nginx -t 2>&1 | tail -2
ss -tlnp | grep ':80 '
grep -n 'X-Real-IP\|X-Forwarded-For' /etc/nginx/sites-available/jujutsu-proxy
