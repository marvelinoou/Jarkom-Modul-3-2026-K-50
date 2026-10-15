#!/bin/bash
# soal17-api.sh - Worker API mencatat IP klien terverifikasi (hanya percaya X-Real-IP dari geto)
# Jalankan di: nanami, todo, dan kirara
# Pemakaian  : bash /root/soal17-api.sh
GETO="192.236.4.2"
PHPV=$(ls /usr/sbin/php-fpm[0-9]* 2>/dev/null | head -1 | sed 's/.*php-fpm//')
[ -z "$PHPV" ] && { echo "php-fpm tidak ditemukan"; exit 1; }
NODE=$(hostname)

# 1. Skrip API
mkdir -p /var/www/api
cat > /var/www/api/index.php <<'PHPEOF'
<?php
header('Content-Type: application/json');
mysqli_report(MYSQLI_REPORT_OFF);

// Hanya proxy terpercaya (geto) yang boleh menyatakan IP klien
const TRUSTED_PROXY = '__GETO__';

$worker = gethostname();
$peer   = $_SERVER['REMOTE_ADDR'] ?? '';
$client = $peer;
if ($peer === TRUSTED_PROXY) {
    $real = trim($_SERVER['HTTP_X_REAL_IP'] ?? '');
    if (filter_var($real, FILTER_VALIDATE_IP)) {
        $client = $real;
    }
}
$path = $_SERVER['REQUEST_URI'] ?? '';

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
    'peer_ip'   => $peer,
    'path'      => $path,
    'log_id'    => $db->insert_id
], JSON_UNESCAPED_SLASHES);
PHPEOF
sed -i "s/__GETO__/$GETO/" /var/www/api/index.php
chown -R www-data:www-data /var/www/api

# 2. Virtual host: tetap hanya geto yang boleh masuk, + log header
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/jujutsu-api
cat > /etc/nginx/sites-available/jujutsu-api <<'NGEOF'
log_format api_realip '$remote_addr real=$http_x_real_ip xff="$http_x_forwarded_for" "$request" $status';

server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;
    root /var/www/api;
    access_log /var/log/nginx/api-realip.log api_realip;

    allow __GETO__;
    deny all;

    location /api {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/api/index.php;
        fastcgi_pass unix:/run/php/php__PHPV__-fpm.sock;
    }
}
NGEOF
sed -i "s/__GETO__/$GETO/; s/__PHPV__/$PHPV/" /etc/nginx/sites-available/jujutsu-api
ln -sf /etc/nginx/sites-available/jujutsu-api /etc/nginx/sites-enabled/jujutsu-api

# 3. Jalankan ulang service
mkdir -p /run/php
service php${PHPV}-fpm restart
nginx -t || exit 1
service nginx restart

sleep 1
echo "===== HASIL $NODE ====="
nginx -t 2>&1 | tail -2
ss -tlnp | grep ':80 '
grep -n 'TRUSTED_PROXY' /var/www/api/index.php | head -1
echo -n "akses lokal /api (harus 403) : "; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/api
