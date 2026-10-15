#!/bin/bash
# soal14-api.sh - Worker API: nginx + php-fpm + log request ke database yaga, hanya geto yang boleh akses
# Jalankan di: nanami, todo, dan kirara
# Pemakaian  : bash /root/soal14-api.sh
GETO="192.236.4.2"
DBHOST="192.236.4.20"
PHPV=$(ls /usr/sbin/php-fpm[0-9]* 2>/dev/null | head -1 | sed 's/.*php-fpm//')
[ -z "$PHPV" ] && { echo "php-fpm tidak ditemukan"; exit 1; }
NODE=$(hostname)

# 1. Skrip API: catat request ke request_logs di yaga
mkdir -p /var/www/api
cat > /var/www/api/index.php <<'PHPEOF'
<?php
header('Content-Type: application/json');
mysqli_report(MYSQLI_REPORT_OFF);

$worker = gethostname();
$client = $_SERVER['REMOTE_ADDR'] ?? '';
$path   = $_SERVER['REQUEST_URI'] ?? '';

$db = mysqli_init();
$db->options(MYSQLI_OPT_CONNECT_TIMEOUT, 3);
if (!@$db->real_connect('192.236.4.20', 'shibuya', 'shibuya50', 'db_shibuya_K50')) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'worker' => $worker, 'message' => 'koneksi database gagal']);
    exit;
}
$stmt = $db->prepare('INSERT INTO request_logs (worker, client_ip, path) VALUES (?, ?, ?)');
$stmt->bind_param('sss', $worker, $client, $path);
if (!$stmt->execute()) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'worker' => $worker, 'message' => 'insert gagal']);
    exit;
}
echo json_encode([
    'status'    => 'ok',
    'worker'    => $worker,
    'client_ip' => $client,
    'path'      => $path,
    'log_id'    => $db->insert_id
], JSON_UNESCAPED_SLASHES);
PHPEOF
chown -R www-data:www-data /var/www/api

# 2. Virtual host: hanya geto yang boleh masuk
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/jujutsu-api <<NGEOF
server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;
    root /var/www/api;

    allow ${GETO};
    deny all;

    location /api {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/api/index.php;
        fastcgi_pass unix:/run/php/php${PHPV}-fpm.sock;
    }
}
NGEOF
ln -sf /etc/nginx/sites-available/jujutsu-api /etc/nginx/sites-enabled/jujutsu-api

# 3. Jalankan service
mkdir -p /run/php
service php${PHPV}-fpm restart
nginx -t || exit 1
service nginx restart

# 4. Autostart saat boot
mkdir -p /root/boot.d
cat > /root/boot.d/api.sh <<BOOTEOF
mkdir -p /run/php
service php${PHPV}-fpm start
service nginx start
BOOTEOF

# 5. Ringkasan
sleep 2
echo "===== HASIL $NODE ====="
echo "hostname      : $NODE"
echo "PHP-FPM versi : $PHPV"
echo -n "ekstensi mysqli : "; php-fpm${PHPV} -m | grep -ci mysqli
nginx -t 2>&1 | tail -2
pgrep -a php-fpm | head -2
ss -tlnp | grep ':80 '
mariadb -h $DBHOST -u shibuya -pshibuya50 -N -e "SELECT COUNT(*) FROM db_shibuya_K50.request_logs" >/dev/null 2>&1 \
    && echo "koneksi DB yaga : OK" || echo "koneksi DB yaga : GAGAL"
echo -n "akses lokal /api (harus 403) : "; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/api
