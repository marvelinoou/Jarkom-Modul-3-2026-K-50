## Langkah 1: jichi

### Konsol

**[Console: jichi]**

### Script

```sh
cat > /root/setup-jichi.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-jichi.sh - Router utama: interface, IPv4 forwarding, NAT, DHCP Relay
# Pemakaian: bash /root/setup-jichi.sh          (setup penuh)
#            bash /root/setup-jichi.sh boot     (dipanggil init.sh saat boot)
MODE="${1:-full}"
PREFIX="192.236"

# 1. Interface
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

# WAN -> NAT1
auto eth0
iface eth0 inet dhcp

# Network 1 (DMZ)
auto eth1
iface eth1 inet static
    address $PREFIX.1.1
    netmask 255.255.255.0

# Network 2 (Divisi A)
auto eth2
iface eth2 inet static
    address $PREFIX.2.1
    netmask 255.255.255.0

# Network 3 (Divisi B)
auto eth3
iface eth3 inet static
    address $PREFIX.3.1
    netmask 255.255.255.0

# Network 4 (Data Center)
auto eth4
iface eth4 inet static
    address $PREFIX.4.1
    netmask 255.255.255.0
IFEOF

if [ "$MODE" = "full" ]; then
    # image debinet tidak punya ifup/ifdown -> pasang alamat langsung dengan ip.
    # eth0 (DHCP dari NAT) tidak disentuh; ia diatur image saat node boot.
    for n in 1 2 3 4; do
        ip addr replace $PREFIX.$n.1/24 dev eth$n
        ip link set eth$n up
    done
    ip -4 -o addr show eth0 | grep -q inet || echo ">> PERINGATAN: eth0 belum punya IP. Restart jichi dari GNS3 (Stop lalu Start)."
fi

# 2. Forwarding + source NAT
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo "nameserver 192.168.122.1" > /etc/resolv.conf
iptables -t nat -C POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null ||
    iptables -t nat -A POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE

# 3. DHCP Relay -> tengen
if ! command -v dhcrelay >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-relay
fi
cat > /etc/default/isc-dhcp-relay <<RLEOF
SERVERS="$PREFIX.4.10"
INTERFACES=""
OPTIONS="-id eth2 -id eth3 -iu eth4"
RLEOF
pgrep -x dhcrelay >/dev/null || rm -f /var/run/dhcrelay.pid
service isc-dhcp-relay restart

# 4. Autostart saat boot (menggantikan init.sh lama)
if [ "$MODE" = "full" ]; then
cat > /root/init.sh <<'INITEOF'
#!/bin/bash
{
    bash /root/setup-jichi.sh boot
    for f in /root/boot.d/*.sh; do [ -f "$f" ] && bash "$f"; done
} > /root/init.log 2>&1
INITEOF
chmod +x /root/init.sh
mkdir -p /root/boot.d
fi

echo "===== HASIL ====="
ip -br a
iptables -t nat -S POSTROUTING
pgrep -a dhcrelay || echo "dhcrelay TIDAK jalan"
SETUP_EOF

bash -n /root/setup-jichi.sh && echo "script OK" && bash /root/setup-jichi.sh
```

### Ekspektasi

Pada instalasi baru, `eth0` sudah punya IP dari NAT:
```
script OK
net.ipv4.ip_forward = 1
===== HASIL =====
lo      UNKNOWN   127.0.0.1/8 ::1/128
eth0    UNKNOWN   192.168.122.xxx/24
eth1    UNKNOWN   192.236.1.1/24 ...
eth2    UNKNOWN   192.236.2.1/24 ...
eth3    UNKNOWN   192.236.3.1/24 ...
eth4    UNKNOWN   192.236.4.1/24 ...
-P POSTROUTING ACCEPT
-A POSTROUTING -s 192.236.0.0/16 -o eth0 -j MASQUERADE
xxx /usr/sbin/dhcrelay -q -id eth2 -id eth3 -iu eth4 192.236.4.10
```

Kalau muncul `>> PERINGATAN: eth0 belum punya IP`, Stop lalu Start jichi di GNS3, lalu cek `ip -br a`.

### Verifikasi tambahan

**[Console: jichi]**
```sh
ping -c 2 8.8.8.8
ping -c 2 google.com
```

Ekspektasi: dua-duanya `0% packet loss`.

---

## Langkah 2: tengen

### Konsol

**[Console: tengen]**

### Script

```sh
cat > /root/setup-tengen.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-tengen.sh - DHCP Server (konfigurasi final soal 2-6)
# Pemakaian: bash /root/setup-tengen.sh          (setup penuh)
#            bash /root/setup-tengen.sh boot     (dipanggil init.sh saat boot)
MODE="${1:-full}"
PREFIX="192.236"

# MAC client. Nilai default = project Marvelino. Kalau MAC di projectmu beda,
# ubah di sini (client akan menampilkan MAC aslinya + perintah sed siap pakai).
MAC_ITADORI="02:42:05:9a:ab:00"
MAC_FUSHIGURO="02:42:c3:6e:65:00"
MAC_ZENIN="02:42:f6:49:44:00"
MAC_OKKOTSU="02:42:ef:c5:90:00"
MAC_INO="02:42:aa:da:e5:00"
MAC_KUSAKABE="02:42:5a:e2:39:00"
MAC_MIWA="02:42:35:f5:07:00"
MAC_KUGISAKI="02:42:7e:5f:c8:00"

# 1. Interface
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $PREFIX.4.10
    netmask 255.255.255.0
    gateway $PREFIX.4.1
    up echo nameserver 192.168.122.1 > /etc/resolv.conf
IFEOF

if [ "$MODE" = "full" ]; then
    # image debinet tidak punya ifup/ifdown -> pasang alamat langsung dengan ip
    ip addr replace $PREFIX.4.10/24 dev eth0
    ip link set eth0 up
    ip route replace default via $PREFIX.4.1 dev eth0
fi
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# 2. isc-dhcp-server
if ! command -v dhcpd >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server
fi
sed -i 's/^INTERFACESv4=.*/INTERFACESv4="eth0"/' /etc/default/isc-dhcp-server

cat > /etc/dhcp/dhcpd.conf <<EOF
authoritative;
ddns-update-style none;

default-lease-time 600;
max-lease-time 7200;

option domain-name-servers $PREFIX.1.2, $PREFIX.1.3;
option domain-search "K50.com";

# Divisi A dipisah per MAC Address (1: = tipe hardware ethernet)
class "divA-pool1" { match hardware; }
subclass "divA-pool1" 1:$MAC_ITADORI;     # itadori
subclass "divA-pool1" 1:$MAC_FUSHIGURO;   # fushiguro

class "divA-pool2" { match hardware; }
subclass "divA-pool2" 1:$MAC_ZENIN;       # zenin
subclass "divA-pool2" 1:$MAC_OKKOTSU;     # okkotsu

# Divisi B dipisah per MAC Address
class "divB-short" { match hardware; }
subclass "divB-short" 1:$MAC_INO;         # ino
subclass "divB-short" 1:$MAC_KUSAKABE;    # kusakabe

class "divB-long" { match hardware; }
subclass "divB-long" 1:$MAC_MIWA;         # miwa

# Network 4 (Data Center) - subnet lokal tengen, tanpa pool dinamis
subnet $PREFIX.4.0 netmask 255.255.255.0 {
}

# Network 2 (Divisi A) - .2.36 s/d .2.69 tidak dialokasikan
subnet $PREFIX.2.0 netmask 255.255.255.0 {
    option routers $PREFIX.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address $PREFIX.2.255;

    pool {
        allow members of "divA-pool1";
        range $PREFIX.2.10 $PREFIX.2.35;
    }
    pool {
        allow members of "divA-pool2";
        range $PREFIX.2.70 $PREFIX.2.95;
    }
}

# Network 3 (Divisi B)
subnet $PREFIX.3.0 netmask 255.255.255.0 {
    option routers $PREFIX.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address $PREFIX.3.255;

    # short lease 30 menit
    pool {
        allow members of "divB-short";
        range $PREFIX.3.10 $PREFIX.3.89;
        default-lease-time 1800;
        max-lease-time 1800;
    }
    # long lease 12 jam
    pool {
        allow members of "divB-long";
        range $PREFIX.3.100 $PREFIX.3.199;
        default-lease-time 43200;
        max-lease-time 43200;
    }
}

# Static lease kugisaki (di luar semua pool)
host kugisaki {
    hardware ethernet $MAC_KUGISAKI;
    fixed-address $PREFIX.3.99;
}
EOF

dhcpd -t -cf /etc/dhcp/dhcpd.conf || exit 1
pgrep -x dhcpd >/dev/null || rm -f /var/run/dhcpd.pid
service isc-dhcp-server restart

# 3. Autostart saat boot (menggantikan init.sh lama)
if [ "$MODE" = "full" ]; then
cat > /root/init.sh <<'INITEOF'
#!/bin/bash
{
    bash /root/setup-tengen.sh boot
    for f in /root/boot.d/*.sh; do [ -f "$f" ] && bash "$f"; done
} > /root/init.log 2>&1
INITEOF
chmod +x /root/init.sh
mkdir -p /root/boot.d
fi

echo "===== HASIL ====="
ip -br a show eth0
service isc-dhcp-server status
ss -ulnp | grep :67
SETUP_EOF

bash -n /root/setup-tengen.sh && echo "script OK" && bash /root/setup-tengen.sh
```

### Ekspektasi

```
script OK
===== HASIL =====
eth0    UNKNOWN   192.236.4.10/24 ...
Status of ISC DHCPv4 server: dhcpd is running.
UNCONN 0  0   0.0.0.0:67   0.0.0.0:*   users:(("dhcpd",pid=...,fd=7))
```

Kalau `dhcpd -t` menolak konfigurasi, script berhenti dan menampilkan baris error-nya. Kirim teks error itu.

---

## Langkah 3: 11 node Debian (image debinet, Debian 13)

### Konsol

**[Console: utahime, shoko, gojo, geto, maki, panda, nanami, todo, kirara, yaga, inumaki]**

Urutan: boleh acak, tapi semua harus selesai sebelum Langkah 4 (client).

- utahime dan shoko **sudah pernah dijalankan** dengan script lama. Cukup paste script di bawah (menimpa file lama), lalu jalankan ulang. Paket tidak diunduh lagi, jadi cepat.
- Node lain: paste script, lalu jalankan satu baris sesuai tabel.

### Script (paste di tiap console)

```sh
cat > /root/setup-node.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-node.sh - Node Debian (non-router, non-DHCP): interface + paket soal 11-20
# Pemakaian: bash /root/setup-node.sh <nama>          (setup penuh)
#            bash /root/setup-node.sh <nama> boot     (dipanggil init.sh saat boot)
NODE="${1:-$(hostname)}"
MODE="${2:-full}"

case "$NODE" in
    utahime) IP=192.236.1.2;  GW=192.236.1.1; PKGS="bind9 bind9-dnsutils curl" ;;
    shoko)   IP=192.236.1.3;  GW=192.236.1.1; PKGS="bind9 bind9-dnsutils curl" ;;
    gojo)    IP=192.236.1.4;  GW=192.236.1.1; PKGS="nginx curl" ;;
    geto)    IP=192.236.4.2;  GW=192.236.4.1; PKGS="nginx curl" ;;
    maki)    IP=192.236.4.3;  GW=192.236.4.1; PKGS="nginx php-fpm curl" ;;
    panda)   IP=192.236.4.4;  GW=192.236.4.1; PKGS="nginx php-fpm curl" ;;
    nanami)  IP=192.236.4.5;  GW=192.236.4.1; PKGS="nginx php-fpm php-mysql mariadb-client curl" ;;
    todo)    IP=192.236.4.6;  GW=192.236.4.1; PKGS="nginx php-fpm php-mysql mariadb-client curl" ;;
    kirara)  IP=192.236.4.7;  GW=192.236.4.1; PKGS="nginx php-fpm php-mysql mariadb-client curl" ;;
    yaga)    IP=192.236.4.20; GW=192.236.4.1; PKGS="mariadb-server curl" ;;
    inumaki) IP=192.236.4.21; GW=192.236.4.1; PKGS="mariadb-server curl" ;;
    *) echo "Nama node tidak dikenal: '$NODE'"; echo "Pakai: bash $0 <utahime|shoko|gojo|geto|maki|panda|nanami|todo|kirara|yaga|inumaki>"; exit 1 ;;
esac

# 1. Interface
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $IP
    netmask 255.255.255.0
    gateway $GW
    up echo nameserver 192.168.122.1 > /etc/resolv.conf
IFEOF

if [ "$MODE" = "full" ]; then
    # image debinet tidak punya ifup/ifdown -> pasang alamat langsung dengan ip
    ip addr replace $IP/24 dev eth0
    ip link set eth0 up
    ip route replace default via $GW dev eth0
fi
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# 2. Paket (hanya download kalau ada yang belum terpasang)
NEED=""
for p in $PKGS; do dpkg -s "$p" >/dev/null 2>&1 || NEED="$NEED $p"; done
if [ -n "$NEED" ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y $NEED
fi

# 3. Autostart saat boot
if [ "$MODE" = "full" ]; then
cat > /root/init.sh <<INITEOF
#!/bin/bash
{
    bash /root/setup-node.sh $NODE boot
    for f in /root/boot.d/*.sh; do [ -f "\$f" ] && bash "\$f"; done
} > /root/init.log 2>&1
INITEOF
chmod +x /root/init.sh
mkdir -p /root/boot.d
fi

# 4. Ringkasan
echo "===== HASIL $NODE ====="
ip -br a show eth0
ip route | grep default
ping -c 1 -W 2 $GW >/dev/null && echo "gateway $GW : OK" || echo "gateway $GW : GAGAL"
ping -c 1 -W 2 8.8.8.8 >/dev/null && echo "internet 8.8.8.8 : OK" || echo "internet 8.8.8.8 : GAGAL"
ping -c 1 -W 2 google.com >/dev/null && echo "DNS google.com : OK" || echo "DNS google.com : GAGAL"
for p in $PKGS; do dpkg -s "$p" >/dev/null 2>&1 && echo "paket $p : terpasang" || echo "paket $p : BELUM"; done
command -v named >/dev/null && named -v
command -v dig >/dev/null && dig -v 2>&1 | head -1
command -v nginx >/dev/null && nginx -v 2>&1
ls /usr/sbin/php-fpm* 2>/dev/null
command -v mariadbd >/dev/null && mariadbd --version
SETUP_EOF

bash -n /root/setup-node.sh && echo "script OK"
```

Ekspektasi setelah paste: hanya satu baris `script OK`. Kalau muncul error sintaks, paste ulang blok di atas.

### Perintah per node

Jalankan **satu baris** sesuai console:

| Console | Perintah | IP | Paket |
|---|---|---|---|
| utahime | `bash /root/setup-node.sh utahime` | 192.236.1.2 | bind9, bind9-dnsutils |
| shoko | `bash /root/setup-node.sh shoko` | 192.236.1.3 | bind9, bind9-dnsutils |
| gojo | `bash /root/setup-node.sh gojo` | 192.236.1.4 | nginx |
| geto | `bash /root/setup-node.sh geto` | 192.236.4.2 | nginx |
| maki | `bash /root/setup-node.sh maki` | 192.236.4.3 | nginx, php-fpm |
| panda | `bash /root/setup-node.sh panda` | 192.236.4.4 | nginx, php-fpm |
| nanami | `bash /root/setup-node.sh nanami` | 192.236.4.5 | nginx, php-fpm, php-mysql, mariadb-client |
| todo | `bash /root/setup-node.sh todo` | 192.236.4.6 | nginx, php-fpm, php-mysql, mariadb-client |
| kirara | `bash /root/setup-node.sh kirara` | 192.236.4.7 | nginx, php-fpm, php-mysql, mariadb-client |
| yaga | `bash /root/setup-node.sh yaga` | 192.236.4.20 | mariadb-server |
| inumaki | `bash /root/setup-node.sh inumaki` | 192.236.4.21 | mariadb-server |

Instalasi pertama bisa makan 1–3 menit per node (paling lama `mariadb-server`). Tunggu sampai baris `===== HASIL ... =====` muncul.

### Ekspektasi per kelompok node

Bagian yang **wajib sama** di semua node: IP, `default via`, tiga baris `OK`, dan semua baris `paket ... : terpasang`. Nomor versi di baris paling bawah bisa sedikit berbeda dari contoh.

**utahime dan shoko** (contoh utahime):
```
===== HASIL utahime =====
eth0    UNKNOWN   192.236.1.2/24 ...
default via 192.236.1.1 dev eth0
gateway 192.236.1.1 : OK
internet 8.8.8.8 : OK
DNS google.com : OK
paket bind9 : terpasang
paket bind9-dnsutils : terpasang
paket curl : terpasang
BIND 9.20.29-1~deb13u1-Debian (Stable Release) <id:...>
DiG 9.20.29-1~deb13u1-Debian
```
shoko: IP `192.236.1.3/24`, selain itu sama.

**gojo dan geto** (contoh gojo):
```
===== HASIL gojo =====
eth0    UNKNOWN   192.236.1.4/24 ...
default via 192.236.1.1 dev eth0
gateway 192.236.1.1 : OK
internet 8.8.8.8 : OK
DNS google.com : OK
paket nginx : terpasang
paket curl : terpasang
nginx version: nginx/1.xx.x
```
geto: IP `192.236.4.2/24`, gateway `192.236.4.1`.

**maki dan panda** (contoh maki):
```
===== HASIL maki =====
eth0    UNKNOWN   192.236.4.3/24 ...
default via 192.236.4.1 dev eth0
gateway 192.236.4.1 : OK
internet 8.8.8.8 : OK
DNS google.com : OK
paket nginx : terpasang
paket php-fpm : terpasang
paket curl : terpasang
nginx version: nginx/1.xx.x
/usr/sbin/php-fpm8.4
```
panda: IP `192.236.4.4/24`. Angka di `php-fpm8.x` mengikuti versi PHP di image. **Catat nama ini**, karena dipakai sebagai nama service di soal 14.

**nanami, todo, kirara** (contoh nanami):
```
===== HASIL nanami =====
eth0    UNKNOWN   192.236.4.5/24 ...
default via 192.236.4.1 dev eth0
gateway 192.236.4.1 : OK
internet 8.8.8.8 : OK
DNS google.com : OK
paket nginx : terpasang
paket php-fpm : terpasang
paket php-mysql : terpasang
paket mariadb-client : terpasang
paket curl : terpasang
nginx version: nginx/1.xx.x
/usr/sbin/php-fpm8.4
```
todo: IP `192.236.4.6/24`. kirara: IP `192.236.4.7/24`.

**yaga dan inumaki** (contoh yaga):
```
===== HASIL yaga =====
eth0    UNKNOWN   192.236.4.20/24 ...
default via 192.236.4.1 dev eth0
gateway 192.236.4.1 : OK
internet 8.8.8.8 : OK
DNS google.com : OK
paket mariadb-server : terpasang
paket curl : terpasang
mariadbd  Ver 11.x.x-MariaDB-... for debian-linux-gnu on x86_64 (Debian ...)
```
inumaki: IP `192.236.4.21/24`.

### Kalau ada yang tidak sesuai

| Gejala | Penyebab | Solusi |
|---|---|---|
| `gateway ... : GAGAL` | jichi atau tengen belum siap | Cek `ip -br a` di jichi. Pastikan `eth1` dan `eth4` punya IP |
| `internet 8.8.8.8 : GAGAL` | NAT di jichi belum aktif | Di jichi: `iptables -t nat -S POSTROUTING` harus ada baris MASQUERADE |
| `DNS google.com : GAGAL` tapi 8.8.8.8 OK | resolver salah | `cat /etc/resolv.conf` harus `nameserver 192.168.122.1` |
| `paket ... : BELUM` | `apt-get` gagal | Baca error di atas baris `HASIL`, lalu jalankan ulang perintah script |
| `invoke-rc.d: policy-rc.d denied execution of start` | Normal, image menolak start otomatis | Abaikan |

### Cek sapu dari jichi (setelah semua 11 node selesai)

**[Console: jichi]**
```sh
for ip in 192.236.1.2 192.236.1.3 192.236.1.4 192.236.4.2 192.236.4.3 192.236.4.4 192.236.4.5 192.236.4.6 192.236.4.7 192.236.4.10 192.236.4.20 192.236.4.21; do
    ping -c 1 -W 1 $ip >/dev/null && echo "$ip OK" || echo "$ip GAGAL"
done
```

Ekspektasi: 12 baris `OK`.
```
192.236.1.2 OK
192.236.1.3 OK
192.236.1.4 OK
192.236.4.2 OK
192.236.4.3 OK
192.236.4.4 OK
192.236.4.5 OK
192.236.4.6 OK
192.236.4.7 OK
192.236.4.10 OK
192.236.4.20 OK
192.236.4.21 OK
```

## Langkah 4: 8 client

### Konsol

**[Console: itadori, fushiguro, zenin, okkotsu, ino, kusakabe, miwa, kugisaki]**

### Script

```sh
cat > /root/setup-client.sh << 'SETUP_EOF'
#!/bin/sh
# /root/setup-client.sh - Client Alpine: DHCP + paket uji (dig, curl, ab)
# Pemakaian: sh /root/setup-client.sh <nama>   (itadori fushiguro zenin okkotsu ino kusakabe miwa kugisaki)
NODE="${1:-$(hostname)}"

case "$NODE" in
    itadori)   VAR=MAC_ITADORI;   DEF=02:42:05:9a:ab:00 ;;
    fushiguro) VAR=MAC_FUSHIGURO; DEF=02:42:c3:6e:65:00 ;;
    zenin)     VAR=MAC_ZENIN;     DEF=02:42:f6:49:44:00 ;;
    okkotsu)   VAR=MAC_OKKOTSU;   DEF=02:42:ef:c5:90:00 ;;
    ino)       VAR=MAC_INO;       DEF=02:42:aa:da:e5:00 ;;
    kusakabe)  VAR=MAC_KUSAKABE;  DEF=02:42:5a:e2:39:00 ;;
    miwa)      VAR=MAC_MIWA;      DEF=02:42:35:f5:07:00 ;;
    kugisaki)  VAR=MAC_KUGISAKI;  DEF=02:42:7e:5f:c8:00 ;;
    *) echo "Nama client tidak dikenal: '$NODE'"; exit 1 ;;
esac

# 1. Interface DHCP (+ minta option 119 domain-search)
cat > /etc/network/interfaces <<IFEOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    udhcpc_opts -O search
IFEOF

MAC="$(ip link show eth0 | awk '/ether/{print $2}')"
echo "===== MAC $NODE ====="
echo "MAC aktual : $MAC"
if [ "$MAC" = "$DEF" ]; then
    echo "Status     : COCOK dengan default di setup-tengen.sh"
else
    echo "Status     : BEDA dari default ($DEF)"
    echo "Jalankan di TENGEN:  sed -i 's/^$VAR=.*/$VAR=\"$MAC\"/' /root/setup-tengen.sh && bash /root/setup-tengen.sh"
fi

# 2. Ambil lease (gagal kalau jichi/tengen belum siap atau MAC belum terdaftar)
ifdown eth0 2>/dev/null; ifup eth0
echo "===== LEASE ====="
ip -4 -br a show eth0

# 3. Paket uji: pakai resolver NAT dulu (DNS DHCP baru hidup setelah soal 11)
echo "nameserver 192.168.122.1" > /etc/resolv.conf
apk update
apk add bind-tools curl apache2-utils

# 4. Kembalikan resolver dari DHCP
ifdown eth0 2>/dev/null; ifup eth0

echo "===== HASIL $NODE ====="
ip -4 -br a show eth0
ip route | grep default
cat /etc/resolv.conf
for c in dig curl ab; do command -v $c >/dev/null && echo "$c : terpasang" || echo "$c : BELUM"; done
SETUP_EOF
```

### Perintah per client

Jalankan **satu baris** sesuai console:

| Console | Perintah | IP yang diharapkan |
|---|---|---|
| itadori | `sh /root/setup-client.sh itadori` | 192.236.2.10–.35 (Pool 1) |
| fushiguro | `sh /root/setup-client.sh fushiguro` | 192.236.2.10–.35 (Pool 1) |
| zenin | `sh /root/setup-client.sh zenin` | 192.236.2.70–.95 (Pool 2) |
| okkotsu | `sh /root/setup-client.sh okkotsu` | 192.236.2.70–.95 (Pool 2) |
| ino | `sh /root/setup-client.sh ino` | 192.236.3.10–.89 (short lease) |
| kusakabe | `sh /root/setup-client.sh kusakabe` | 192.236.3.10–.89 (short lease) |
| miwa | `sh /root/setup-client.sh miwa` | 192.236.3.100–.199 (long lease) |
| kugisaki | `sh /root/setup-client.sh kugisaki` | 192.236.3.99 (fixed) |

### Ekspektasi (contoh itadori)

```
===== MAC itadori =====
MAC aktual : 02:42:05:9a:ab:00
Status     : COCOK dengan default di setup-tengen.sh
===== LEASE =====
eth0   UP   192.236.2.10/24
...
===== HASIL itadori =====
eth0   UP   192.236.2.10/24
default via 192.236.2.1 dev eth0
search K50.com
nameserver 192.236.1.2
nameserver 192.236.1.3
dig : terpasang
curl : terpasang
ab : terpasang
```

### Kalau muncul `Status : BEDA`

MAC node di project-mu tidak sama dengan project Marvelino. Client akan gagal mendapat IP sampai MAC-nya didaftarkan di tengen.

1. Salin baris `sed -i ...` yang ditampilkan client tadi.
2. Jalankan di **[Console: tengen]**. Perintah itu sekaligus menjalankan ulang `setup-tengen.sh`.
3. Di client itu, jalankan `ifdown eth0; ifup eth0`.

Ulangi untuk tiap client yang MAC-nya beda.

---

## Langkah 5: cek akhir

### Ping sapu semua host infrastruktur

**[Console: jichi]**
```sh
for ip in 192.236.1.2 192.236.1.3 192.236.1.4 192.236.4.2 192.236.4.3 192.236.4.4 192.236.4.5 192.236.4.6 192.236.4.7 192.236.4.10 192.236.4.20 192.236.4.21; do
    ping -c 1 -W 1 $ip >/dev/null && echo "$ip OK" || echo "$ip GAGAL"
done
```

Ekspektasi: 12 baris `OK`.

```
192.236.1.2 OK
192.236.1.3 OK
192.236.1.4 OK
192.236.4.2 OK
192.236.4.3 OK
192.236.4.4 OK
192.236.4.5 OK
192.236.4.6 OK
192.236.4.7 OK
192.236.4.10 OK
192.236.4.20 OK
192.236.4.21 OK
```

### Cek lease masuk lewat relay

**[Console: tengen]**
```sh
awk '/^lease /{ip=$2} /hardware ethernet/{print ip, $3}' /var/lib/dhcp/dhcpd.leases | sort -t. -k3,3n -k4,4n -u
```

Ekspektasi: 7 pasangan IP dan MAC. Kugisaki tidak tercatat di file ini karena memakai `fixed-address`. Itu perilaku normal dhcpd.

```
192.236.2.10 02:42:05:9a:ab:00;
192.236.2.11 02:42:c3:6e:65:00;
192.236.2.70 02:42:f6:49:44:00;
192.236.2.71 02:42:ef:c5:90:00;
192.236.3.10 02:42:aa:da:e5:00;
192.236.3.11 02:42:5a:e2:39:00;
192.236.3.100 02:42:35:f5:07:00;
```

Alamat bisa bergeser sesuai urutan client meminta lease. Yang pasti, tiap client harus berada di pool-nya.

### Uji jalur lintas network dan `ab`

**[Console: kusakabe]**
```sh
ping -c 2 192.236.4.10
ping -c 2 192.236.1.4
ab -V | head -1
```

Ekspektasi: ping ke tengen dan gojo berhasil dengan `ttl=63` (melewati satu router, jichi). `ab` menampilkan versinya.

```
64 bytes from 192.236.4.10: seq=0 ttl=63 time=...
64 bytes from 192.236.1.4: seq=0 ttl=63 time=...
This is ApacheBench, Version 2.3 <$Revision: ...$>
```

---

## Checklist sebelum Soal 11

- [ ] jichi: `ping google.com` berhasil dan `dhcrelay` berjalan.
- [ ] tengen: `dhcpd is running` dan listen di `:67`.
- [ ] 11 node Debian: gateway, internet, dan semua paket terpasang.
- [ ] 8 client dapat IP dari pool yang benar, dan `dig`, `curl`, `ab` terpasang.
- [ ] Ping sapu dari jichi: 12 baris `OK`.

---

## Troubleshooting

| Gejala | Penyebab | Solusi |
|---|---|---|
| `bash: $'\r': command not found` | Script dicopy dari repo (CRLF) | Paste ulang dari dokumen ini |
| `apt-get update` gagal di node Debian | NAT atau resolver belum siap | Pastikan Langkah 1 sukses, `cat /etc/resolv.conf`, `ping 8.8.8.8` |
| Client tidak dapat IP | MAC belum terdaftar di tengen, atau relay mati | Lihat bagian `Status : BEDA`. Di jichi: `pgrep -a dhcrelay` |
| `dhcpd -t` error | Salah ketik di `setup-tengen.sh` | Paste ulang blok script, baca baris error-nya |
| `ifup: interface eth0 already configured` | State ifupdown tersisa | `ifdown --force eth0; ifup eth0` |
| Node tidak responsif setelah restart | Node belum Started di GNS3 | Start node, lalu cek `/root/init.log` |