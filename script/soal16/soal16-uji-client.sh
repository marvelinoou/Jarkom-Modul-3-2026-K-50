#!/bin/bash
# soal15-geto.sh - Internal Load Balancer (nginx): upstream api_cluster, Weighted Round Robin 3:1
# Jalankan di: geto
# Pemakaian  : bash /root/soal15-geto.sh
NANAMI="192.236.4.5"
TODO="192.236.4.6"

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/jujutsu-lb <<NGEOF
upstream api_cluster {
    zone api_cluster 64k;
    server ${NANAMI} weight=3;
    server ${TODO} weight=1;
}

server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;

    location /api {
        proxy_pass http://api_cluster;
        proxy_set_header Host \$host;
        add_header X-Upstream \$upstream_addr always;
    }
}
NGEOF
ln -sf /etc/nginx/sites-available/jujutsu-lb /etc/nginx/sites-enabled/jujutsu-lb

nginx -t || exit 1
service nginx restart

# Autostart saat boot
mkdir -p /root/boot.d
cat > /root/boot.d/nginx.sh <<BOOTEOF
service nginx start
BOOTEOF

sleep 1
echo "===== HASIL geto ====="
nginx -t 2>&1 | tail -2
pgrep -a nginx | head -2
ss -tlnp | grep ':80 '
grep -A4 'upstream' /etc/nginx/sites-available/jujutsu-lb
