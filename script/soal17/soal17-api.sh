#!/bin/bash
# soal16-gojo.sh - Public Reverse Proxy (nginx): path-based routing
#   /     -> maki, panda (Round Robin)
#   /api  -> geto
# Jalankan di: gojo
# Pemakaian  : bash /root/soal16-gojo.sh
MAKI="192.236.4.3"
PANDA="192.236.4.4"
GETO="192.236.4.2"

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/jujutsu-proxy <<'NGEOF'
# Root (/) -> worker frontend, Round Robin
upstream frontend_cluster {
    zone frontend_cluster 64k;
    server MAKI_IP;
    server PANDA_IP;
}

# /api -> internal load balancer geto
upstream geto_lb {
    server GETO_IP;
}

server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;

    location / {
        proxy_pass http://frontend_cluster;
        proxy_set_header Host $host;
        add_header X-Gojo-Upstream $upstream_addr always;
    }

    location /api {
        proxy_pass http://geto_lb;
        proxy_set_header Host $host;
        add_header X-Gojo-Upstream $upstream_addr always;
    }
}
NGEOF
sed -i "s/MAKI_IP/$MAKI/; s/PANDA_IP/$PANDA/; s/GETO_IP/$GETO/" /etc/nginx/sites-available/jujutsu-proxy
ln -sf /etc/nginx/sites-available/jujutsu-proxy /etc/nginx/sites-enabled/jujutsu-proxy

nginx -t || exit 1
service nginx restart

# Autostart saat boot
mkdir -p /root/boot.d
cat > /root/boot.d/nginx.sh <<BOOTEOF
service nginx start
BOOTEOF

sleep 1
echo "===== HASIL gojo ====="
nginx -t 2>&1 | tail -2
pgrep -a nginx | head -2
ss -tlnp | grep ':80 '
grep -A4 'upstream' /etc/nginx/sites-available/jujutsu-proxy
