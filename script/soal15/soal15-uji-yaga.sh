#!/bin/bash
# soal14-web.sh - Worker frontend: nginx + php-fpm, halaman hostname, hanya gojo yang boleh akses
# Jalankan di: maki dan panda
# Pemakaian  : bash /root/soal14-web.sh
GOJO="192.236.1.4"
PHPV=$(ls /usr/sbin/php-fpm[0-9]* 2>/dev/null | head -1 | sed 's/.*php-fpm//')
[ -z "$PHPV" ] && { echo "php-fpm tidak ditemukan"; exit 1; }
NODE=$(hostname)

# 1. Halaman frontend (menampilkan hostname)
mkdir -p /var/www/frontend
cat > /var/www/frontend/index.php <<'PHPEOF'
<?php
echo "<h1>Jujutsu High - Frontend</h1>\n";
echo "<p>Worker: " . htmlspecialchars(gethostname()) . "</p>\n";
PHPEOF
chown -R www-data:www-data /var/www/frontend

# 2. Virtual host: hanya gojo yang boleh masuk
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/jujutsu-frontend <<NGEOF
server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;
    root /var/www/frontend;
    index index.php;

    allow ${GOJO};
    deny all;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHPV}-fpm.sock;
    }
}
NGEOF
ln -sf /etc/nginx/sites-available/jujutsu-frontend /etc/nginx/sites-enabled/jujutsu-frontend

# 3. Jalankan service
mkdir -p /run/php
service php${PHPV}-fpm restart
nginx -t || exit 1
service nginx restart

# 4. Autostart saat boot (dipanggil init.sh lewat boot.d)
mkdir -p /root/boot.d
cat > /root/boot.d/web.sh <<BOOTEOF
mkdir -p /run/php
service php${PHPV}-fpm start
service nginx start
BOOTEOF

# 5. Ringkasan
sleep 2
echo "===== HASIL $NODE ====="
echo "hostname      : $NODE"
echo "PHP-FPM versi : $PHPV"
nginx -t 2>&1 | tail -2
pgrep -a php-fpm | head -2
ss -tlnp | grep ':80 '
ls /run/php/
echo -n "akses lokal (harus 403) : "; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
