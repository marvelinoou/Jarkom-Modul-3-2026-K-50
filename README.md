# Jarkom-Modul-3-2026-K-50

## Member

| No  | Nama                   | NRP        | Pengerjaan Soal |
| --- | ---------------------- | ---------- | --------------- |
| 1   | Marvelino Davas        | 5027251085 | 1-10            |
| 2   | Nathania Tiara Wahyudi | 5027251089 | 11-20           |

---

## Ringkasan Topologi

Prefix IP kelompok: `192.236`. Semua subnet memakai `/24`. `<xxxx>` diisi `K50`, sehingga domain-search menjadi `K50.com`.

| Jaringan  | Network          | Gateway (jichi)         | Isi                                          |
| --------- | ---------------- | ----------------------- | -------------------------------------------- |
| WAN       | 192.168.122.0/24 | `eth0` (DHCP dari NAT1) | Akses internet                               |
| Network 1 | 192.236.1.0/24   | `eth1` 192.236.1.1      | DMZ: utahime, shoko, gojo                    |
| Network 2 | 192.236.2.0/24   | `eth2` 192.236.2.1      | Divisi A: itadori, fushiguro, zenin, okkotsu |
| Network 3 | 192.236.3.0/24   | `eth3` 192.236.3.1      | Divisi B: ino, kusakabe, miwa, kugisaki      |
| Network 4 | 192.236.4.0/24   | `eth4` 192.236.4.1      | Data Center: tengen, geto, worker, database  |

Catatan umum pengerjaan:

- Semua script disimpan di `/root` node terkait dan salinannya ada di folder [script/](script/).
- Image `debinet` tidak memakai systemd. File `/root/init.sh` dijalankan otomatis setiap node boot, sehingga autostart layanan dipasang di sana.
- Alamat client dari pool dinamis bisa berbeda antar screenshot (misalnya itadori `.2.10` atau `.2.11`). Urutan client meminta lease setelah node di-restart menentukan siapa yang mendapat alamat pertama di pool. Yang dijamin oleh konfigurasi adalah **pool**-nya, bukan angka alamat tertentu, kecuali kugisaki yang selalu `.3.99`.

---

### Soal 1: Konektivitas Dasar, IPv4 Forwarding, dan Source NAT
> Ketika Curtain menutup Shibuya, jalur komunikasi antar zona Jujutsu High terputus. Pulihkan konektivitas dasar dengan mengonfigurasi jichi: eth0 memperoleh WAN dari NAT, sedangkan eth1–eth4 menjadi gateway Network 1–4 sesuai tabel pemetaan. Aktifkan IPv4 forwarding dan source NAT, lalu tetapkan IP statis host infrastruktur sesuai tabel spesifikasi. Buktikan konektivitas setiap host ke gateway dan akses eksternal dari host yang relevan.

#### Tabel IP host infrastruktur

| Node    | IP           | Gateway     | Peran                  |
| ------- | ------------ | ----------- | ---------------------- |
| utahime | 192.236.1.2  | 192.236.1.1 | DNS Master             |
| shoko   | 192.236.1.3  | 192.236.1.1 | DNS Slave              |
| gojo    | 192.236.1.4  | 192.236.1.1 | Public Reverse Proxy   |
| geto    | 192.236.4.2  | 192.236.4.1 | Internal Load Balancer |
| maki    | 192.236.4.3  | 192.236.4.1 | Worker frontend        |
| panda   | 192.236.4.4  | 192.236.4.1 | Worker frontend        |
| nanami  | 192.236.4.5  | 192.236.4.1 | Worker API utama       |
| todo    | 192.236.4.6  | 192.236.4.1 | Worker API utama       |
| kirara  | 192.236.4.7  | 192.236.4.1 | Worker API cadangan    |
| tengen  | 192.236.4.10 | 192.236.4.1 | DHCP Server            |
| yaga    | 192.236.4.20 | 192.236.4.1 | Database Master        |
| inumaki | 192.236.4.21 | 192.236.4.1 | Database Slave         |

#### Konfigurasi jichi (`/etc/network/interfaces`)

```
auto lo
iface lo inet loopback

# WAN -> NAT1
auto eth0
iface eth0 inet dhcp

# Network 1 (DMZ)
auto eth1
iface eth1 inet static
    address 192.236.1.1
    netmask 255.255.255.0

# Network 2 (Divisi A)
auto eth2
iface eth2 inet static
    address 192.236.2.1
    netmask 255.255.255.0

# Network 3 (Divisi B)
auto eth3
iface eth3 inet static
    address 192.236.3.1
    netmask 255.255.255.0

# Network 4 (Data Center)
auto eth4
iface eth4 inet static
    address 192.236.4.1
    netmask 255.255.255.0
```

eth0 mengambil alamat dari NAT1 lewat DHCP, sedangkan eth1 sampai eth4 diberi alamat `.1` di tiap network sehingga menjadi gateway bagi host di network tersebut.

#### Aktifkan IPv4 forwarding dan source NAT di jichi (`/root/soal01-jichi.sh`)

```bash
#!/bin/bash
PREFIX="192.236"

# IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# Source NAT: Network 1-4 keluar lewat eth0 (NAT1)
iptables -t nat -C POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null ||
    iptables -t nat -A POSTROUTING -s $PREFIX.0.0/16 -o eth0 -j MASQUERADE

# Resolver untuk persiapan awal
echo "nameserver 192.168.122.1" > /etc/resolv.conf
```

- `ip_forward=1` membuat jichi meneruskan paket antar network, bukan membuangnya.
- MASQUERADE hanya untuk trafik yang keluar lewat `eth0` (internet). NAT1 tidak mengenal alamat `192.236.x.x`, jadi alamat sumbernya diganti menjadi IP eth0 jichi. Trafik antar network internal tidak di-NAT, sehingga alamat asli host tetap terlihat.
- Aturan NAT dicek dulu dengan `-C` supaya tidak dobel ketika script dijalankan ulang.

#### Konfigurasi host infrastruktur (`/etc/network/interfaces`)

Contoh untuk tengen. Host lain memakai pola yang sama dengan IP dan gateway sesuai tabel; file lengkap tiap node ada di [script/soal01/interfaces/](script/soal01/interfaces/).

```
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.236.4.10
    netmask 255.255.255.0
    gateway 192.236.4.1
    up echo nameserver 192.168.122.1 > /etc/resolv.conf
```

#### Verifikasi di jichi

```bash
ip -br a
ip route
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
ping -c 2 8.8.8.8
ping -c 2 google.com
```

![Verifikasi jichi](screenshot/soal01-verifikasi-jichi.png)

eth1 sampai eth4 sudah menjadi gateway `.1` di tiap network, `ip_forward = 1`, ada satu aturan MASQUERADE `-o eth0`, dan jichi bisa mengakses internet.

#### Verifikasi di host infrastruktur

```bash
ip -br a show eth0
ip route
ping -c 2 192.236.X.1     # gateway
ping -c 2 8.8.8.8         # akses eksternal lewat source NAT jichi
ping -c 1 google.com
```

Diambil tiga host sebagai perwakilan: utahime (Network 1), tengen dan yaga (Network 4). utahime dan yaga juga melakukan ping lintas network untuk membuktikan routing dua arah lewat jichi.

![Verifikasi utahime](screenshot/soal01-verifikasi-utahime.png)

![Verifikasi tengen](screenshot/soal01-verifikasi-tengen.png)

![Verifikasi yaga](screenshot/soal01-verifikasi-yaga.png)

Ping ke gateway memiliki `ttl=64`, sedangkan ping lintas network (utahime ke `192.236.4.10` dan `192.236.4.20`, yaga ke `192.236.1.4`) memiliki `ttl=63`. Selisih satu menunjukkan paket melewati satu router, yaitu jichi.

----

### Soal 2: DHCP Server pada tengen
> Tengen, penjaga pusat distribusi di Data Center, harus mengambil alih pengalokasian alamat bagi wilayah yang membutuhkan konfigurasi dinamis. Konfigurasikan isc-dhcp-server pada [PREFIX IP].4.10. Deklarasikan Network 4 ([PREFIX IP].4.0/24) sebagai subnet lokal tanpa pool dinamis, lalu siapkan scope DHCP untuk Network 2 ([PREFIX IP].2.0/24) dan Network 3 ([PREFIX IP].3.0/24). Validasi konfigurasi dan pastikan service aktif tanpa error "No subnet declaration".

#### Install dan konfigurasi di tengen (`/root/soal02-tengen.sh`)

```bash
#!/bin/bash
PREFIX="192.236"

if ! command -v dhcpd >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server
fi

# dhcpd hanya listen di eth0 (Network 4)
sed -i 's/^INTERFACESv4=.*/INTERFACESv4="eth0"/' /etc/default/isc-dhcp-server

cat > /etc/dhcp/dhcpd.conf <<EOF
authoritative;
ddns-update-style none;

default-lease-time 600;
max-lease-time 7200;

# Network 4 (Data Center) - subnet lokal tengen, tanpa pool dinamis
subnet $PREFIX.4.0 netmask 255.255.255.0 {
}

# Network 2 (Divisi A)
subnet $PREFIX.2.0 netmask 255.255.255.0 {
    range $PREFIX.2.10 $PREFIX.2.35;
    range $PREFIX.2.70 $PREFIX.2.95;
    option routers $PREFIX.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address $PREFIX.2.255;
}

# Network 3 (Divisi B)
subnet $PREFIX.3.0 netmask 255.255.255.0 {
    range $PREFIX.3.10 $PREFIX.3.89;
    range $PREFIX.3.100 $PREFIX.3.199;
    option routers $PREFIX.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address $PREFIX.3.255;
}
EOF

# Validasi dulu, baru restart
dhcpd -t -cf /etc/dhcp/dhcpd.conf || exit 1
pgrep -x dhcpd >/dev/null || rm -f /var/run/dhcpd.pid
service isc-dhcp-server restart
service isc-dhcp-server status
```

Subnet Network 4 dideklarasikan kosong. Tanpa deklarasi ini `dhcpd` menolak berjalan di `eth0` dengan pesan "No subnet declaration for eth0", karena interface tempat ia listen tidak punya subnet yang dikenali. Scope Network 2 dan Network 3 tetap dideklarasikan walaupun tengen tidak berada di sana, karena request dari kedua network itu akan datang lewat relay (soal 3).

#### Verifikasi di tengen

```bash
dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server status
grep INTERFACESv4 /etc/default/isc-dhcp-server
ps aux | grep dhcpd
ss -ulnp | grep :67
```

![Verifikasi tengen](screenshot/soal02-verifikasi-tengen.png)

`dhcpd -t` lolos tanpa error "No subnet declaration", service berjalan, dan `dhcpd` listen di UDP 67 pada `eth0`.

----

### Soal 3: DHCP Relay pada jichi
> Permintaan alamat dari Divisi A dan Divisi B tidak dapat menyeberangi subnet secara langsung. Konfigurasikan jichi sebagai DHCP Relay menuju tengen ([PREFIX IP].4.10), menggunakan eth2 untuk Network 2 dan eth3 untuk Network 3. Buktikan bahwa client dari kedua subnet berhasil memperoleh lease melalui relay.

#### Install dan konfigurasi relay di jichi (`/root/soal03-jichi.sh`)

```bash
#!/bin/bash
PREFIX="192.236"

if ! command -v dhcrelay >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-relay
fi

# eth2/eth3 = sisi client (downstream), eth4 = sisi tengen (upstream).
# Tanpa eth4, balasan dari tengen dibuang oleh relay.
cat > /etc/default/isc-dhcp-relay <<EOF
SERVERS="$PREFIX.4.10"
INTERFACES=""
OPTIONS="-id eth2 -id eth3 -iu eth4"
EOF

pgrep -x dhcrelay >/dev/null || rm -f /var/run/dhcrelay.pid
service isc-dhcp-relay restart
service isc-dhcp-relay status
```

`eth2` dan `eth3` dipasang sebagai interface downstream (menerima request client), sedangkan `eth4` sebagai upstream ke tengen. Percobaan pertama hanya dengan `INTERFACES="eth2 eth3"` gagal: capture di tengen menunjukkan request sudah diteruskan dan tengen sudah membalas ke `192.236.2.1`, tetapi relay membuang balasan itu karena datang dari interface yang tidak ia dengarkan, sehingga tidak ada client yang mendapat lease.

```bash
cat /etc/default/isc-dhcp-relay
ps -e -o pid,args | grep dhcrelay
```

![Relay di jichi](screenshot/soal03-relay-jichi.png)

#### Konfigurasi delapan client (`/etc/network/interfaces`)

```
auto lo
iface lo inet loopback

# -O search: minta DHCP option 119 (domain-search) ke server
auto eth0
iface eth0 inet dhcp
    udhcpc_opts -O search
```

#### Minta lease di client

```bash
ip link show eth0
ifdown eth0; ifup eth0
ip a
ip route
```

Client Network 2 (itadori):

![Lease itadori](screenshot/soal03-lease-itadori.png)

Client Network 3 (ino):

![Lease ino](screenshot/soal03-lease-ino.png)

itadori mendapat `192.236.2.11` dengan gateway `192.236.2.1`, dan ino mendapat `192.236.3.11` dengan gateway `192.236.3.1`. Keduanya diberikan oleh `192.236.4.10`, padahal tengen berada di Network 4. Ini hanya mungkin karena request diteruskan oleh relay di jichi.

----

### Soal 4: Dua Pool DHCP pada Network 2 dengan DHCP Class
> Agar tim Dev dan Support di Divisi A menerima jatah alamat yang berbeda, atur dua pool DHCP pada Network 2. Tetapkan Pool 1 ([PREFIX IP].2.10–[PREFIX IP].2.35) untuk itadori dan fushiguro, serta Pool 2 ([PREFIX IP].2.70–[PREFIX IP].2.95) untuk zenin dan okkotsu. Rentang [PREFIX IP].2.36–[PREFIX IP].2.69 tidak boleh dialokasikan. Karena seluruh client berada pada subnet yang sama, gunakan DHCP class berdasarkan MAC Address atau Client ID untuk memisahkan kedua kelompok.

#### Ambil MAC Address tiap client

```bash
ip link show eth0
```

| Client    | MAC Address       | Kelas        |
| --------- | ----------------- | ------------ |
| itadori   | 02:42:05:9a:ab:00 | `divA-pool1` |
| fushiguro | 02:42:c3:6e:65:00 | `divA-pool1` |
| zenin     | 02:42:f6:49:44:00 | `divA-pool2` |
| okkotsu   | 02:42:ef:c5:90:00 | `divA-pool2` |

MAC address ini tetap sama walaupun node di-restart atau container dibuat ulang, sehingga aman dipakai sebagai dasar kelas.

#### Perubahan `dhcpd.conf` di tengen (`/root/soal04-tengen.sh`)

```
# Divisi A dipisah per MAC Address (1: = tipe hardware ethernet)
class "divA-pool1" { match hardware; }
subclass "divA-pool1" 1:02:42:05:9a:ab:00;   # itadori
subclass "divA-pool1" 1:02:42:c3:6e:65:00;   # fushiguro

class "divA-pool2" { match hardware; }
subclass "divA-pool2" 1:02:42:f6:49:44:00;   # zenin
subclass "divA-pool2" 1:02:42:ef:c5:90:00;   # okkotsu

# Network 2 (Divisi A) - .2.36 s/d .2.69 tidak dialokasikan
subnet 192.236.2.0 netmask 255.255.255.0 {
    option routers 192.236.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.236.2.255;

    pool {
        allow members of "divA-pool1";
        range 192.236.2.10 192.236.2.35;
    }
    pool {
        allow members of "divA-pool2";
        range 192.236.2.70 192.236.2.95;
    }
}
```

- `class ... { match hardware; }` membuat kelas yang anggotanya ditentukan dari hardware address client.
- `subclass ... 1:<MAC>` mendaftarkan MAC ke kelas. `1:` adalah kode tipe hardware Ethernet; nilai dari `match hardware` selalu diawali tipe hardware, jadi tanpa `1:` MAC tidak akan pernah cocok.
- `allow members of` membuat tiap pool hanya melayani anggota kelasnya.
- Rentang `.2.36` sampai `.2.69` tidak masuk `range` mana pun, sehingga tidak pernah dialokasikan.

```bash
grep -n "divA\|range 192.236.2" /etc/dhcp/dhcpd.conf
```

![Config soal 4 di tengen](screenshot/soal04-config-tengen.png)

#### Terapkan di tengen, lalu renew di client Network 2

```bash
bash /root/soal04-tengen.sh     # tengen
```

```bash
ip link show eth0               # client Network 2
ifdown eth0; ifup eth0
ip -4 -o addr show eth0
```

Perwakilan Pool 1 (itadori):

![Lease itadori](screenshot/soal04-lease-itadori.png)

Perwakilan Pool 2 (zenin):

![Lease zenin](screenshot/soal04-lease-zenin.png)

itadori mendapat `192.236.2.11` (Pool 1) dan zenin mendapat `192.236.2.71` (Pool 2). fushiguro dan okkotsu dibuktikan bersama seluruh client di soal 7.

----

### Soal 5: Short Lease, Long Lease, dan DHCP Options pada Network 3
> Setiap tim lapangan memiliki durasi operasi yang berbeda. Pada Network 3, berikan short lease 30 menit (1800 detik) kepada ino dan kusakabe, serta long lease 12 jam (43200 detik) kepada miwa. Gunakan pool short lease [PREFIX IP].3.10–[PREFIX IP].3.89 dan pool long lease [PREFIX IP].3.100–[PREFIX IP].3.199. Sesuaikan default-lease-time dan max-lease-time untuk setiap kelas client. Berikan pula DHCP options berupa DNS [PREFIX IP].1.2 dan [PREFIX IP].1.3, serta domain-search <xxxx>.com.

#### Perubahan `dhcpd.conf` di tengen (`/root/soal05-tengen.sh`)

```
# DHCP options untuk semua client
option domain-name-servers 192.236.1.2, 192.236.1.3;
option domain-search "K50.com";

# Divisi B dipisah per MAC Address
class "divB-short" { match hardware; }
subclass "divB-short" 1:02:42:aa:da:e5:00;   # ino
subclass "divB-short" 1:02:42:5a:e2:39:00;   # kusakabe

class "divB-long" { match hardware; }
subclass "divB-long" 1:02:42:35:f5:07:00;    # miwa

# Network 3 (Divisi B)
subnet 192.236.3.0 netmask 255.255.255.0 {
    option routers 192.236.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.236.3.255;

    # short lease 30 menit
    pool {
        allow members of "divB-short";
        range 192.236.3.10 192.236.3.89;
        default-lease-time 1800;
        max-lease-time 1800;
    }
    # long lease 12 jam
    pool {
        allow members of "divB-long";
        range 192.236.3.100 192.236.3.199;
        default-lease-time 43200;
        max-lease-time 43200;
    }
}
```

- Lease time dipasang di dalam masing-masing pool, sehingga tiap kelas client mendapat durasi sendiri. `default-lease-time` dan `max-lease-time` dibuat sama supaya client tidak bisa meminta lease lebih panjang dari kelasnya.
- DNS dan domain-search ditaruh di tingkat global supaya berlaku untuk Network 2 dan Network 3 sekaligus.
- `default-lease-time 600` dan `max-lease-time 7200` di bagian atas file adalah nilai global untuk client yang tidak masuk pool berlease khusus, yaitu Network 2 dan kugisaki.

```bash
grep -n "domain-\|divB\|range 192.236.3\|lease-time" /etc/dhcp/dhcpd.conf
```

![Config soal 5 di tengen](screenshot/soal05-config-tengen.png)

#### Terapkan di tengen, lalu renew di client Network 3

```bash
bash /root/soal05-tengen.sh     # tengen
```

```bash
ifdown eth0; ifup eth0          # client Network 3
ip -4 -o addr show eth0
cat /etc/resolv.conf
```

Perwakilan short lease (ino):

![Lease ino](screenshot/soal05-lease-ino.png)

Perwakilan long lease (miwa):

![Lease miwa](screenshot/soal05-lease-miwa.png)

ino mendapat alamat di pool short lease dengan `lease time 1800`, sedangkan miwa mendapat `192.236.3.100` di pool long lease dengan `lease time 43200`. Di kedua client, `resolv.conf` berisi `search K50.com`, `nameserver 192.236.1.2`, dan `nameserver 192.236.1.3`.

Baris `search K50.com` baru muncul setelah `udhcpc_opts -O search` ditambahkan di `/etc/network/interfaces` client. `udhcpc` bawaan alpinet tidak meminta option 119 secara default, jadi tanpa baris itu server tidak mengirimkannya walaupun sudah dikonfigurasi.

Pada tahap ini kugisaki belum mendapat alamat, karena MAC-nya bukan anggota kelas mana pun. Itu diselesaikan di soal 6.

----

### Soal 6: Static Lease untuk kugisaki
> Kugisaki ditetapkan sebagai personel VIP yang harus mempertahankan alamat yang sama setiap kali terhubung. Buat DHCP static lease berdasarkan MAC Address client tersebut dengan fixed address [PREFIX IP].3.99. Pastikan alamat ini berada di luar seluruh pool dinamis, validasi konfigurasi server, lalu renew lease pada client. Buktikan bahwa alamat yang diterima sesuai dengan reservasi.

#### Perubahan `dhcpd.conf` di tengen (`/root/soal06-tengen.sh`)

```
# Static lease kugisaki (di luar pool .3.10-.3.89 dan .3.100-.3.199)
host kugisaki {
    hardware ethernet 02:42:7e:5f:c8:00;
    fixed-address 192.236.3.99;
}
```

`192.236.3.99` terletak di antara pool short lease (berakhir di `.3.89`) dan pool long lease (mulai di `.3.100`), sehingga tidak bisa diberikan ke client lain. Script soal 6 berisi konfigurasi DHCP final; isi lengkapnya ada di [script/soal06/soal06-tengen.sh](script/soal06/soal06-tengen.sh).

#### Validasi di tengen

```bash
bash /root/soal06-tengen.sh     # tengen: dhcpd -t lalu restart
grep -n -A3 "host kugisaki" /etc/dhcp/dhcpd.conf
grep -n "range 192.236.3" /etc/dhcp/dhcpd.conf
dhcpd -t -cf /etc/dhcp/dhcpd.conf
```

![Config soal 6 di tengen](screenshot/soal06-config-tengen.png)

#### Renew di kugisaki

```bash
ip link show eth0
ifdown eth0; ifup eth0
ip -4 -o addr show eth0
```

![Lease kugisaki](screenshot/soal06-lease-kugisaki.png)

Renew diulang sekali lagi untuk membuktikan alamatnya tetap sama setiap kali terhubung:

![Renew kugisaki](screenshot/soal06-renew-kugisaki.png)

Kedua renew menghasilkan `192.236.3.99` dari `192.236.4.10`. Lease time kugisaki 600 detik karena host dengan fixed address tidak masuk pool mana pun, sehingga memakai `default-lease-time` global; soal tidak menentukan lease time untuk kugisaki.

----

### Soal 7: Verifikasi Konfigurasi Client dan Pencocokan Lease
> Setelah aturan alokasi diterapkan, pastikan setiap client menerima konfigurasi jaringan sesuai wilayahnya: subnet mask 255.255.255.0 (/24), gateway dan broadcast address yang benar, DNS [PREFIX IP].1.2 serta [PREFIX IP].1.3, dan domain-search yang ditentukan. Periksa IP address dan routing seluruh client Divisi A dan Divisi B, kemudian cocokkan lease dengan /var/lib/dhcp/dhcpd.leases pada tengen. Pastikan tidak ada alamat yang bertabrakan atau berada di luar kebijakan pool.

#### Periksa konfigurasi di tiap client

```bash
ip -4 -o addr show eth0
ip route
cat /etc/resolv.conf
```

![Client itadori](screenshot/soal07-client-itadori.png)

![Client fushiguro](screenshot/soal07-client-fushiguro.png)

![Client zenin](screenshot/soal07-client-zenin.png)

![Client okkotsu](screenshot/soal07-client-okkotsu.png)

![Client ino](screenshot/soal07-client-ino.png)

![Client kusakabe](screenshot/soal07-client-kusakabe.png)

![Client miwa](screenshot/soal07-client-miwa.png)

![Client kugisaki](screenshot/soal07-client-kugisaki.png)

Rekap seluruh client:

| Client    | IP / mask        | Broadcast     | Gateway     | DNS        | Search  | Kebijakan                          |
| --------- | ---------------- | ------------- | ----------- | ---------- | ------- | ---------------------------------- |
| itadori   | 192.236.2.10/24  | 192.236.2.255 | 192.236.2.1 | .1.2, .1.3 | K50.com | Pool 1 (.2.10 sampai .2.35)        |
| fushiguro | 192.236.2.11/24  | 192.236.2.255 | 192.236.2.1 | .1.2, .1.3 | K50.com | Pool 1                             |
| zenin     | 192.236.2.70/24  | 192.236.2.255 | 192.236.2.1 | .1.2, .1.3 | K50.com | Pool 2 (.2.70 sampai .2.95)        |
| okkotsu   | 192.236.2.71/24  | 192.236.2.255 | 192.236.2.1 | .1.2, .1.3 | K50.com | Pool 2                             |
| ino       | 192.236.3.10/24  | 192.236.3.255 | 192.236.3.1 | .1.2, .1.3 | K50.com | Short lease (.3.10 sampai .3.89)   |
| kusakabe  | 192.236.3.11/24  | 192.236.3.255 | 192.236.3.1 | .1.2, .1.3 | K50.com | Short lease                        |
| miwa      | 192.236.3.100/24 | 192.236.3.255 | 192.236.3.1 | .1.2, .1.3 | K50.com | Long lease (.3.100 sampai .3.199)  |
| kugisaki  | 192.236.3.99/24  | 192.236.3.255 | 192.236.3.1 | .1.2, .1.3 | K50.com | Fixed address                      |

#### Cocokkan dengan `dhcpd.leases` di tengen (`/root/soal07-tengen.sh`)

File lease mencatat riwayat, jadi satu IP bisa muncul berkali-kali. Script berikut mengambil entri terakhir tiap IP:

```bash
#!/bin/bash
awk '
/^lease /            { ip=$2; state=""; mac=""; ends="" }
/^  ends /           { ends=$3" "$4; sub(";","",ends) }
/^  binding state /  { state=$3; sub(";","",state) }
/hardware ethernet / { mac=$3; sub(";","",mac) }
/^}/                 { if (ip!="") { S[ip]=state; M[ip]=mac; E[ip]=ends } }
END { for (i in S) printf "%-15s %-18s %-7s ends %s UTC\n", i, M[i], S[i], E[i] }
' /var/lib/dhcp/dhcpd.leases | sort -t. -k3,3n -k4,4n
```

```bash
bash /root/soal07-tengen.sh
grep -cE "^lease 192\.236\.2\.(3[6-9]|[45][0-9]|6[0-9]) " /var/lib/dhcp/dhcpd.leases
```

![Lease di tengen](screenshot/soal07-leases-tengen.png)

- Pasangan IP dan MAC di server sama dengan yang terlihat di client, dan tiap IP hanya dipegang satu MAC, jadi tidak ada alamat yang bertabrakan.
- Jumlah lease di rentang terlarang `.2.36` sampai `.2.69` adalah `0`.
- kugisaki tidak muncul di file ini. `dhcpd` tidak mencatat alamat `fixed-address` ke `dhcpd.leases`, sehingga reservasinya dibuktikan dari sisi client (soal 6).

----

### Soal 8: Packet Capture Proses DORA
> Sebelum Curtain dibuka kembali, buktikan bahwa proses pemberian alamat berjalan sesuai protokol. Lakukan packet capture saat salah satu client Network 2 atau Network 3 meminta lease baru. Gunakan tcpdump pada tengen atau jalur menuju Data Center untuk menunjukkan urutan DHCPDISCOVER → DHCPOFFER → DHCPREQUEST → DHCPACK. Identifikasi alamat server, alamat yang diberikan, lease time, dan field giaddr. Pastikan nilai giaddr sesuai dengan interface jichi yang menerima request dari subnet client.

#### Script capture di tengen (`/root/soal08-tengen.sh`)

```bash
#!/bin/bash
# Filter chaddr (udp[36:6]) supaya renew client lain tidak ikut tertangkap.
timeout 60 tcpdump -i eth0 -n -vvv -c 4 \
    'udp port 67 and udp[36:4] = 0x0242059a and udp[40:2] = 0xab00' 2>&1 | tee /root/soal08-dora.txt

echo "===== RINGKASAN ====="
grep -E "DHCP-Message|Your-IP|Gateway-IP|Server-ID|Lease-Time" /root/soal08-dora.txt
```

Filter `udp[36:6]` mencocokkan field `chaddr` dengan MAC itadori, supaya paket renew dari client lain tidak ikut terhitung. `timeout 60` membuat capture berhenti sendiri kalau dalam 60 detik tidak ada paket.

#### Urutan pengujian

```bash
ifdown eth0                     # 1. itadori: lepas lease lama
bash /root/soal08-tengen.sh     # 2. tengen: mulai capture
ifup eth0                       # 3. itadori: minta lease baru (dalam 60 detik)
```

`ifdown` dijalankan lebih dulu supaya paket DHCPRELEASE tidak ikut masuk ke dalam empat paket yang ditangkap.

#### Hasil capture

Paket Discover dan Offer:

![DORA bagian 1](screenshot/soal08-dora-1.png)

Paket Request, ACK, dan ringkasan:

![DORA bagian 2](screenshot/soal08-dora-2.png)

#### Analisis

| Field                 | Nilai                            | Keterangan                                       |
| --------------------- | -------------------------------- | ------------------------------------------------ |
| Urutan pesan          | Discover → Offer → Request → ACK | Keempatnya memakai `xid 0xab700a7c` yang sama    |
| Alamat server         | 192.236.4.10                     | Server-ID (option 54), yaitu tengen              |
| Alamat yang diberikan | 192.236.2.10                     | `Your-IP` (yiaddr), dari Pool 1 milik itadori    |
| Lease time            | 600 detik                        | Option 51, sesuai `default-lease-time` Network 2 |
| giaddr                | 192.236.2.1                      | `Gateway-IP`, yaitu `eth2` jichi                 |

Nilai giaddr `192.236.2.1` adalah alamat `eth2` jichi, interface yang menerima broadcast dari itadori di Network 2. Dari nilai inilah tengen tahu bahwa request berasal dari subnet `192.236.2.0/24` dan harus dilayani dari scope Network 2. Paket Discover dan Request tiba dari `192.236.4.1` (alamat `eth4` jichi) dengan `hops 1`, dan balasan server dikirim unicast ke `192.236.2.1`, yang menunjukkan request memang lewat relay.

Option `Unknown (119), length 9: 3.75.53.48.3.99.111.109.0` adalah domain-search `K50.com` dalam format label DNS: `3` diikuti `75.53.48` (`K50`), `3` diikuti `99.111.109` (`com`), lalu `0` sebagai penutup.

----

### Soal 9: Simulasi Gangguan DHCP Relay
> Sebuah gangguan memutus jalur relay dan membuat permintaan alamat tidak sampai ke Data Center. Hentikan service DHCP Relay pada jichi, lalu paksa salah satu client di Network 2 atau Network 3 meminta lease baru dan catat gejalanya. Pulihkan service relay, ulangi permintaan DHCP, lalu buktikan bahwa client kembali memperoleh alamat dari pool yang benar dengan gateway semula.

#### Script di jichi (`/root/soal09-jichi.sh`)

```bash
#!/bin/bash
# Pemakaian: bash /root/soal09-jichi.sh down   -> hentikan relay
#            bash /root/soal09-jichi.sh up     -> pulihkan relay
case "$1" in
    down) service isc-dhcp-relay stop ;;
    up)   pgrep -x dhcrelay >/dev/null || rm -f /var/run/dhcrelay.pid
          service isc-dhcp-relay start ;;
    *)    echo "pemakaian: $0 down|up"; exit 1 ;;
esac
service isc-dhcp-relay status
pgrep -a dhcrelay || echo "dhcrelay tidak berjalan"
```

#### Script di client ino (`/root/soal09-client.sh`)

```sh
#!/bin/sh
ifdown eth0 2>/dev/null          # lepas lease lama
ip addr flush dev eth0
ip link set eth0 up              # ifdown mematikan link, nyalakan lagi sebelum udhcpc
if udhcpc -i eth0 -n -q -t 3 -T 2 -O search; then
    ifup eth0                    # kembali ke mode normal (udhcpc jalan di background)
else
    echo ">> GAGAL: tidak ada DHCPOFFER (relay mati?)"
fi
ip -br a show eth0
ip route
```

`udhcpc -n -t 3 -T 2` membatasi client mencoba tiga kali dengan jeda dua detik, lalu menyerah. Tanpa batas ini, client akan terus mencoba tanpa henti saat relay mati.

#### Hentikan relay, lalu minta lease dari ino

```bash
bash /root/soal09-jichi.sh down     # jichi
```

![Relay dimatikan](screenshot/soal09-relay-down-jichi.png)

```bash
sh /root/soal09-client.sh           # ino
```

![Gejala di ino](screenshot/soal09-gejala-ino.png)

Gejala: ino mengirim DHCPDISCOVER tiga kali tanpa pernah menerima DHCPOFFER, `eth0` tidak punya alamat IPv4, dan tabel routing kosong (tidak ada default gateway). Broadcast client berhenti di jichi karena tidak ada lagi yang meneruskannya ke tengen.

Setelah `down`, script jichi bisa saja masih menampilkan satu baris PID `dhcrelay`. Itu proses yang baru dihentikan dan belum hilang dari tabel proses saat `pgrep` berjalan. Relay benar-benar berhenti, terlihat dari ino yang gagal mendapat lease.

#### Pulihkan relay, lalu ulangi dari ino

```bash
bash /root/soal09-jichi.sh up       # jichi
```

![Relay dipulihkan](screenshot/soal09-relay-up-jichi.png)

```bash
sh /root/soal09-client.sh           # ino
ping -c 2 192.236.3.1
cat /etc/resolv.conf
```

![ino pulih](screenshot/soal09-pulih-ino.png)

Setelah relay pulih, ino kembali mendapat alamat dari pool short lease (`.3.10` sampai `.3.89`) dengan lease 1800 detik, gateway `192.236.3.1` seperti sebelum gangguan, dan DNS serta domain-search kembali terpasang.

----

### Soal 10: Autostart dan Ketahanan Setelah Restart
> Setelah gangguan Shibuya tertangani, pastikan pemulihan bertahan setelah restart. Aktifkan autostart DHCP Server pada tengen dan DHCP Relay pada jichi, lalu restart kedua node. Verifikasi status layanan, IP, gateway, lease, dan konektivitas client Network 2–3. Pastikan kebijakan Pool 1, Pool 2, short lease, long lease, dan fixed address tetap berlaku.

Image `debinet` tidak memakai systemd, sehingga `systemctl enable` tidak tersedia. Sebagai gantinya, image ini menjalankan `/root/init.sh` secara otomatis setiap node boot, dan direktori `/root` serta `/etc/network` tersimpan permanen. Autostart dipasang di file tersebut.

#### `/root/init.sh` di tengen

```bash
#!/bin/bash
bash /root/soal06-tengen.sh > /root/init.log 2>&1
```

#### `/root/init.sh` di jichi

```bash
#!/bin/bash
{
    bash /root/soal01-jichi.sh
    bash /root/soal03-jichi.sh
} > /root/init.log 2>&1
```

```bash
chmod +x /root/init.sh
```

Script yang dipanggil memeriksa dulu apakah paketnya sudah terpasang, menulis ulang konfigurasi, lalu menyalakan layanan, sehingga aman dijalankan berulang kali. Ketika container node dibuat ulang (misalnya saat project dibuka kembali), paket `isc-dhcp-relay` dan `isc-dhcp-server` ikut hilang; `init.sh` memasangnya ulang secara otomatis lewat internet, lalu menyalakan layanannya tanpa perintah manual.

#### Restart jichi dan tengen, lalu verifikasi

Seluruh node di-stop lalu di-start dari GNS3. Tanpa menjalankan perintah apa pun secara manual:

```bash
ip -br a                            # jichi
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
ps -e -o pid,args | grep dhcrelay
cat /etc/default/isc-dhcp-relay
```

![jichi setelah restart](screenshot/soal10-restart-jichi.png)

```bash
ip -br a show eth0                  # tengen
ip route
service isc-dhcp-server status
ps -e -o pid,args | grep dhcpd
```

![tengen setelah restart](screenshot/soal10-restart-tengen.png)

IP, forwarding, NAT, relay di jichi, dan DHCP server di tengen langsung aktif setelah boot. PID `dhcrelay` dan `dhcpd` yang kecil menunjukkan keduanya dinyalakan oleh `init.sh` sejak awal boot.

#### Minta lease ulang di client

Satu client untuk tiap kebijakan:

```bash
ifdown eth0; ifup eth0
ip route
ping -c 2 192.236.X.1
ping -c 2 8.8.8.8
```

Pool 1 (itadori):

![itadori setelah restart](screenshot/soal10-lease-itadori.png)

Pool 2 (zenin):

![zenin setelah restart](screenshot/soal10-lease-zenin.png)

Short lease (ino):

![ino setelah restart](screenshot/soal10-lease-ino.png)

Long lease (miwa):

![miwa setelah restart](screenshot/soal10-lease-miwa.png)

Fixed address (kugisaki):

![kugisaki setelah restart](screenshot/soal10-lease-kugisaki.png)

| Client   | IP            | Lease | Gateway     | Ping gateway | Ping 8.8.8.8 | Kebijakan     |
| -------- | ------------- | ----- | ----------- | ------------ | ------------ | ------------- |
| itadori  | 192.236.2.10  | 600   | 192.236.2.1 | ok           | ok           | Pool 1        |
| zenin    | 192.236.2.70  | 600   | 192.236.2.1 | ok           | ok           | Pool 2        |
| ino      | 192.236.3.10  | 1800  | 192.236.3.1 | ok           | ok           | Short lease   |
| miwa     | 192.236.3.100 | 43200 | 192.236.3.1 | ok           | ok           | Long lease    |
| kugisaki | 192.236.3.99  | 600   | 192.236.3.1 | ok           | ok           | Fixed address |

#### Lease di tengen setelah restart

```bash
bash /root/soal07-tengen.sh
```

![Lease tengen setelah restart](screenshot/soal10-leases-tengen.png)

Setelah restart, DHCP Server dan DHCP Relay hidup sendiri, setiap client menerima alamat dari pool yang benar, dan seluruh kebijakan (Pool 1, Pool 2, short lease, long lease, fixed address) tetap berlaku.

----

### Soal 11:
> Utahime dan Shoko ditugaskan membangun sistem penamaan domain resmi agar seluruh pos tidak perlu menghafal alamat IP mentah. Konfigurasikan BIND9 pada utahime sebagai DNS Master dan shoko sebagai DNS Slave untuk mengelola domain jujutsu.<xxxx>.com. Atur SOA record, NS delegasi untuk kedua server, dan terapkan allow-transfer dari Master ke Slave. Pastikan file zona berhasil tersinkronisasi otomatis ke shoko saat nomor serial di utahime dinaikkan, lalu buktikan dengan melakukan query dig ke kedua server dari salah satu client.

#### Cek kesiapan node **utahime** dan **shoko**

```bash
named -v
ip -br a show eth0
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a5f9137e-0fe2-41e7-8bcc-17635000dbdb" />

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/e5ff1f02-e7ed-4f93-8ef3-3be82bc87590" />

#### Konfigurasi DNS Master **utahime**

```bash
mkdir -p /etc/bind/zones

cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.236.0.0/16; };
    dnssec-validation no;
};
EOF

cat > /etc/bind/named.conf.local << 'EOF'
zone "jujutsu.K50.com" {
    type primary;
    file "/etc/bind/zones/db.jujutsu.K50.com";
    notify yes;
    also-notify { 192.236.1.3; };
    allow-transfer { 192.236.1.3; };
};
EOF

cat > /etc/bind/zones/db.jujutsu.K50.com << 'EOF'
$TTL 3600
@       IN      SOA     utahime.jujutsu.K50.com. admin.jujutsu.K50.com. (
                        2026101401
                        3600
                        900
                        1209600
                        300 )

@       IN      NS      utahime.jujutsu.K50.com.
@       IN      NS      shoko.jujutsu.K50.com.

utahime IN      A       192.236.1.2
shoko   IN      A       192.236.1.3
EOF

chown -R root:bind /etc/bind/zones
chmod 755 /etc/bind/zones
chmod 644 /etc/bind/zones/db.jujutsu.K50.com

named-checkconf && echo "named.conf OK"
named-checkzone jujutsu.K50.com /etc/bind/zones/db.jujutsu.K50.com
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/28adff9d-4edc-4fa9-bd93-7a651c21c7b8" />

#### Jalankan BIND di utahime

```bash
service named restart
sleep 2
pgrep -a named
ss -ulnp | grep :53
ss -tlnp | grep :53
dig @127.0.0.1 jujutsu.K50.com SOA +short
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/cd637e08-4deb-4f8f-8b7d-744cf5ebd807" />

#### Konfigurasi DNS Slave **shoko**

```bash
cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.236.0.0/16; };
    dnssec-validation no;
    masterfile-format text;
};
EOF

cat > /etc/bind/named.conf.local << 'EOF'
zone "jujutsu.K50.com" {
    type secondary;
    file "/var/cache/bind/db.jujutsu.K50.com";
    primaries { 192.236.1.2; };
    allow-transfer { none; };
};
EOF

chown -R bind:bind /var/cache/bind
named-checkconf && echo "named.conf OK"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/89db6d1a-6211-4208-9679-176e549b2f64" />

#### Jalankan BIND di shoko dan cek hasil transfer

```bash
service named restart
sleep 5
pgrep -a named
ls -l /var/cache/bind/
dig @127.0.0.1 jujutsu.K50.com SOA +short
cat /var/cache/bind/db.jujutsu.K50.com
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/bf39223e-3464-4d85-bce2-8e12e4a1f859" />

#### Uji dari client (kondisi awal) **itadori**

```bash
dig @192.236.1.2 jujutsu.K50.com SOA +short
dig @192.236.1.3 jujutsu.K50.com SOA +short
dig @192.236.1.2 jujutsu.K50.com NS +short
dig @192.236.1.3 jujutsu.K50.com NS +short
dig @192.236.1.2 jujutsu.K50.com SOA | grep flags
dig @192.236.1.3 jujutsu.K50.com SOA | grep flags
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/3b4ac2d2-bea9-4736-83c8-eabf18f4c3ef" />

#### Uji sinkronisasi otomatis (naikkan serial di Master) **utahime**

```bash
cat >> /etc/bind/zones/db.jujutsu.K50.com << 'EOF'
gojo    IN      A       192.236.1.4
EOF

sed -i 's/2026101401/2026101402/' /etc/bind/zones/db.jujutsu.K50.com
named-checkzone jujutsu.K50.com /etc/bind/zones/db.jujutsu.K50.com
rndc reload jujutsu.K50.com
sleep 3
dig @127.0.0.1 jujutsu.K50.com SOA +short
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/50bfa346-ffbb-4509-8c11-9542b27e6168" />

#### Selanjutnya cek di slave **shoko**

```bash
sleep 3
dig @127.0.0.1 jujutsu.K50.com SOA +short
dig @127.0.0.1 gojo.jujutsu.K50.com +short
grep gojo /var/cache/bind/db.jujutsu.K50.com
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/ea590063-dd07-4ec3-bb84-09e30c5a0f15" />

Terakhir, bukti dari client **itadori**

```bash
for s in 192.236.1.2 192.236.1.3; do echo -n "$s -> serial "; dig +short SOA jujutsu.K50.com @$s | awk '{print $3}'; done
dig @192.236.1.2 gojo.jujutsu.K50.com +short
dig @192.236.1.3 gojo.jujutsu.K50.com +short
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a6eb04aa-1d3e-479a-911a-982b10e31c42" />

#### Uji pembatasan zone transfer

shoko *harus diizinkan*

```bash
dig AXFR jujutsu.K50.com @192.236.1.2
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/b2a8fd0e-7dfa-45cd-9e61-ded53a5f7b6b" />

itadori *harus ditolak*

```bash
dig AXFR jujutsu.K50.com @192.236.1.2
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/0d6af9dc-fccf-4cd3-977e-f90586358637" />

#### Autostart BIND saat node restart **utahime** dan **shoko**

```bash
mkdir -p /root/boot.d
echo 'service named start' > /root/boot.d/named.sh
cat /root/boot.d/named.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d63f7e14-2b7b-4a8c-a40d-ca9888f1fd09" />

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/903ef6e8-a1bc-4487-baba-1da9d76deb8a" />

----

### Soal 12:
> Peta domain harus memetakan pintu masuk utama dan tetap bisa mencari alamat di luar kawasan Shibuya. Pada utahime, buat A record jujutsu.<xxxx>.com yang mengarah ke gojo, serta CNAME www yang merujuk ke domain utama tersebut. Buat pula Reverse DNS (zona PTR) untuk melacak IP gojo kembali ke domain resminya, dan aktifkan fitur DNS Forwarder pada BIND9 mengarah ke IP gateway internet (192.168.122.1). Uji dari client dengan dig untuk mengecek CNAME, PTR, dan buktikan client tetap bisa melakukan ping ke domain internet seperti google.com.

#### Perbarui zona utama

**utahime**

```bash
cat > /etc/bind/zones/db.jujutsu.K50.com << 'EOF'
$TTL 3600
@       IN      SOA     utahime.jujutsu.K50.com. admin.jujutsu.K50.com. (
                        2026101403
                        3600
                        900
                        1209600
                        300 )

@       IN      NS      utahime.jujutsu.K50.com.
@       IN      NS      shoko.jujutsu.K50.com.

@       IN      A       192.236.1.4
www     IN      CNAME   jujutsu.K50.com.

utahime IN      A       192.236.1.2
shoko   IN      A       192.236.1.3
gojo    IN      A       192.236.1.4
EOF

named-checkzone jujutsu.K50.com /etc/bind/zones/db.jujutsu.K50.com
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/61c8e2ae-03e6-4cd0-9b21-36de85878776" />

#### Buat reverse zone

**utahime**

```bash
cat > /etc/bind/named.conf.local << 'EOF'
zone "jujutsu.K50.com" {
    type primary;
    file "/etc/bind/zones/db.jujutsu.K50.com";
    notify yes;
    also-notify { 192.236.1.3; };
    allow-transfer { 192.236.1.3; };
};

zone "1.236.192.in-addr.arpa" {
    type primary;
    file "/etc/bind/zones/db.1.236.192";
};
EOF

cat > /etc/bind/zones/db.1.236.192 << 'EOF'
$TTL 3600
@       IN      SOA     utahime.jujutsu.K50.com. admin.jujutsu.K50.com. (
                        2026101401
                        3600
                        900
                        1209600
                        300 )

@       IN      NS      utahime.jujutsu.K50.com.

4       IN      PTR     jujutsu.K50.com.
EOF

chown -R root:bind /etc/bind/zones
chmod 644 /etc/bind/zones/db.1.236.192

named-checkzone 1.236.192.in-addr.arpa /etc/bind/zones/db.1.236.192
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/89c41832-ad94-42b5-a589-cd6f50fcff0f" />

#### Aktifkan DNS Forwarder

**utahime**

```bash
cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.236.0.0/16; };
    forwarders { 192.168.122.1; };
    forward first;
    dnssec-validation no;
};
EOF

named-checkconf && echo "named.conf OK"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/97d31d3e-c973-4135-8904-f15a137efc22" />

#### Restart BIND dan cek lokal

**utahime**

```bash
service named restart
sleep 3
dig @127.0.0.1 jujutsu.K50.com SOA +short
dig @127.0.0.1 jujutsu.K50.com +short
dig @127.0.0.1 www.jujutsu.K50.com +noall +answer
dig @127.0.0.1 -x 192.236.1.4 +noall +answer
dig @127.0.0.1 google.com +short
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/81c06bcc-d3e4-41ea-9d5e-4f58c5d7d8f1" />

#### Aktifkan forwarder di Slave dan pastikan zona tersinkron

**shoko**

```bash
cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.236.0.0/16; };
    forwarders { 192.168.122.1; };
    forward first;
    dnssec-validation no;
    masterfile-format text;
};
EOF

named-checkconf && echo "named.conf OK"
service named restart
sleep 5
dig @127.0.0.1 jujutsu.K50.com SOA +short
dig @127.0.0.1 www.jujutsu.K50.com +noall +answer
dig @127.0.0.1 google.com +short
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/18feb426-59b8-464c-8c33-99e1d1c468f9" />

#### Uji dari client

**itadori**

```bash
dig @192.236.1.2 jujutsu.K50.com +short
dig @192.236.1.3 jujutsu.K50.com +short
dig www.jujutsu.K50.com +noall +answer
dig -x 192.236.1.4 +noall +answer
dig -x 192.236.1.4 | grep flags
ping -c 2 google.com
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/665f8d89-ad50-4e0d-b93b-52421d24ff6d" />

#### Uji dari client lain

**kusakabe**

```bash
dig www.jujutsu.K50.com +short
dig -x 192.236.1.4 +short
ping -c 2 google.com
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/ba93ca5f-91d7-4362-b325-af7d4d5b73ef" />

----

### Soal 13:
> Kepala Sekolah Yaga dan Inumaki mendirikan database terpusat yang redundan agar log aktivitas kutukan tetap aman tersimpan. Konfigurasikan MariaDB pada yaga sebagai DB-Master dan inumaki sebagai DB-Slave. Buat database db_shibuya_<xxxx> beserta tabel request_logs di Master, aktifkan binary logging (log-bin, server-id), lalu hubungkan inumaki sebagai Slave yang menyalin data secara realtime dengan CHANGE MASTER TO. Berikan hak akses remote bagi seluruh node di Network 4, lalu buktikan replikasi berhasil dengan memasukkan data baru di Master dan memeriksa hasilnya di Slave.

#### Cek kesiapan node

**yaga** dan **inumaki**

```bash
mariadbd --version
ip -br a show eth0
ls /var/lib/mysql | head -5
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/6df35142-28fe-4fcd-af1a-928fc023f0c1" />

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a5e43b39-b3d7-4435-b876-caa1db648718" />

#### Konfigurasi dan jalankan Master

**yaga**

```bash
cat > /etc/mysql/mariadb.conf.d/99-replication.cnf << 'EOF'
[mysqld]
bind-address = 0.0.0.0
skip-name-resolve
server-id = 1
log_bin = /var/lib/mysql/mysql-bin
EOF

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb restart
sleep 5
pgrep -a mariadbd
ss -tlnp | grep 3306
mariadb -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','log_bin');"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a4800998-c5a6-445e-a9f3-4271eeb9b91e" />

#### Buat user replikasi

**yaga**

```bash
mariadb -e "CREATE USER 'repl'@'192.236.4.21' IDENTIFIED BY 'replpass50'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'192.236.4.21'; FLUSH PRIVILEGES;"
mariadb -t -e "SELECT user, host FROM mysql.user WHERE user='repl';"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/20c81938-5226-40ed-993a-e60d12b1e706" />

#### Buat database, tabel, dan user remote Network 4

**yaga**

```bash
mariadb << 'EOF'
CREATE DATABASE db_shibuya_K50;
USE db_shibuya_K50;
CREATE TABLE request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    worker VARCHAR(50) NOT NULL,
    client_ip VARCHAR(45) DEFAULT NULL,
    path VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE USER 'shibuya'@'192.236.4.%' IDENTIFIED BY 'shibuya50';
GRANT ALL PRIVILEGES ON db_shibuya_K50.* TO 'shibuya'@'192.236.4.%';
FLUSH PRIVILEGES;
EOF

mariadb -t -e "SHOW DATABASES LIKE 'db_shibuya%'; DESCRIBE db_shibuya_K50.request_logs;"
mariadb -t -e "SELECT user, host FROM mysql.user WHERE user IN ('shibuya','repl');"
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/f0fb1ff6-a35e-4c12-ba8b-0a7fd84bf856" />

#### Cek file binlog di Master

**yaga**

```bash
mariadb -t -e "SHOW BINARY LOGS; SHOW MASTER STATUS;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d0964509-f656-49cb-b20a-11b4b5f4c447" />

#### Konfigurasi dan jalankan Slave

**inumaki**

```bash
cat > /etc/mysql/mariadb.conf.d/99-replication.cnf << 'EOF'
[mysqld]
bind-address = 0.0.0.0
skip-name-resolve
server-id = 2
relay_log = /var/lib/mysql/relay-bin
read_only = 1
EOF

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb restart
sleep 5
pgrep -a mariadbd
mariadb -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','read_only');"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/86d010c1-b22d-44c1-9272-51d99df47635" />

#### Hubungkan Slave ke Master

**inumaki**

```bash
mariadb -e "CHANGE MASTER TO MASTER_HOST='192.236.4.20', MASTER_USER='repl', MASTER_PASSWORD='replpass50', MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=4; START SLAVE;"
sleep 5
mariadb -e "SHOW SLAVE STATUS\G" | egrep "Slave_IO_State|Master_Host|Master_Log_File|Read_Master_Log_Pos|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_IO_Error|Last_SQL_Error"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/33048fdc-b997-429f-bf5f-69d1253306eb" />

#### Cek DB, tabel, dan user sudah tereplikasi

**inumaki**

```bash
mariadb -t -e "SHOW DATABASES LIKE 'db_shibuya%'; DESCRIBE db_shibuya_K50.request_logs;"
mariadb -t -e "SELECT user, host FROM mysql.user WHERE user IN ('shibuya','repl');"
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/783a81e7-c67f-46a5-804a-fb6e6b7ca2f4" />

#### Bukti replikasi, insert di Master, cek di Slave

**yaga**

```bash
mariadb -e "INSERT INTO db_shibuya_K50.request_logs (worker, client_ip, path) VALUES ('uji-replikasi-1','192.236.2.10','/tes1'),('uji-replikasi-2','192.236.3.10','/tes2');"
mariadb -t -e "SELECT * FROM db_shibuya_K50.request_logs;"
mariadb -t -e "SHOW MASTER STATUS;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9013d4ab-1c5c-4513-a15a-82b5e40e6bb3" />

**inumaki**

```bash
sleep 2
mariadb -t -e "SELECT * FROM db_shibuya_K50.request_logs;"
mariadb -e "SHOW SLAVE STATUS\G" | egrep "Read_Master_Log_Pos|Exec_Master_Log_Pos|Seconds_Behind_Master"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/b22d31e4-b711-44f4-9bf3-effdf36cceeb" />

#### Tes hak akses remote dari node Network 4

**nanami**

```bash
mariadb -h 192.236.4.20 -u shibuya -pshibuya50 -e "SELECT worker, path FROM db_shibuya_K50.request_logs;"
mariadb -h 192.236.4.21 -u shibuya -pshibuya50 -e "SELECT worker, path FROM db_shibuya_K50.request_logs;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9d9e8145-b37d-4479-afbf-f2a9385ee4b7" />

#### Autostart MariaDB saat node restart
/run hilang tiap boot, jadi folder /run/mysqld harus dibuat ulang oleh script boot.

**yaga** dan **inumaki**

```bash
mkdir -p /root/boot.d
cat > /root/boot.d/mariadb.sh << 'EOF'
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb start
EOF
cat /root/boot.d/mariadb.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/32b63bb9-8216-4129-9e8d-007bda59d723" />

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/2eb6508a-8641-4874-bbb9-36935496baf8" />

----

### Soal 14:
> Para penyihir lapangan bersiaga di Data Center sebagai pekerja backend untuk memproses aplikasi. Pasang Nginx dan PHP-FPM pada maki dan panda untuk menyajikan web frontend yang menampilkan hostname masing-masing. Pada nanami, todo, dan kirara, siapkan layanan API yang mencatat log request ke database yaga. Konfigurasikan virtual host agar worker merespons domain layanan yang ditentukan. Batasi akses langsung dari klien ke worker, web worker hanya menerima trafik melalui jalur proxy web yang ditentukan, sedangkan worker API hanya menerima trafik melalui geto. Uji bahwa akses langsung dari klien ditolak, sementara akses melalui reverse proxy tetap berhasil.


#### Worker frontend

**maki** dan **panda**

```bash
cat > /root/setup-web.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-web.sh - Worker frontend (maki, panda): nginx + php-fpm
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
SETUP_EOF

bash -n /root/setup-web.sh && echo "script OK" && bash /root/setup-web.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/4aa19301-2f8c-46ca-af53-858e5cebef4f" />

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/551f116d-7e84-4004-99d9-981a7fffd107" />

#### Worker API

**nanami**, **todo** dan **kirara**

```bash
cat > /root/setup-api.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-api.sh - Worker API (nanami, todo, kirara): nginx + php-fpm + log ke yaga
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
SETUP_EOF

bash -n /root/setup-api.sh && echo "script OK" && bash /root/setup-api.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/e9383bd7-4779-487b-a6cc-06202a03b19f" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/f72c2041-7f34-4048-88c3-c326ac4107f3" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/bf6027e6-cbf7-4520-ab17-e1a2e3b19537" />

#### Uji akses lewat jalur proxy (yang diizinkan)

**gojo, ke worker frontend**

```bash
for h in 192.236.4.3 192.236.4.4; do echo "== $h"; curl -s -H "Host: jujutsu.K50.com" http://$h/; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/049e6999-3272-4417-b2e8-1adfd14f82fc" />

**geto, ke worker API**

```bash
for h in 192.236.4.5 192.236.4.6 192.236.4.7; do echo "== $h"; curl -s -H "Host: jujutsu.K50.com" http://$h/api; echo; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9886c37b-7e76-4ad3-aac0-7a4309139423" />

#### Uji akses langsung dari klien (harus ditolak)

**itadori (Network 2) dan kusakabe (Network 3)**

```bash
for h in 192.236.4.3 192.236.4.4; do echo -n "$h / -> "; curl -s -o /dev/null -w "%{http_code}\n" http://$h/; done
for h in 192.236.4.5 192.236.4.6 192.236.4.7; do echo -n "$h /api -> "; curl -s -o /dev/null -w "%{http_code}\n" http://$h/api; done
echo "--- Host header dipalsukan:"
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: jujutsu.K50.com" http://192.236.4.3/
echo "--- detail respons:"
curl -i http://192.236.4.5/api | head -3
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/abe4d32e-210b-44c4-9396-3e2a8a4688a9" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d64cd19e-a6eb-4e4b-90f4-317acc847e38" />

Membuktikan worker API benar-benar hanya menerima geto, bukan semua node Network 4
**yaga**

```bash
curl -s -o /dev/null -w "yaga -> nanami /api : %{http_code}\n" http://192.236.4.5/api
curl -s -o /dev/null -w "yaga -> maki /      : %{http_code}\n" http://192.236.4.3/
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/fe1f0c59-6507-42e7-94af-30daa0096153" />

#### Cek log tercatat di database

**yaga**

```bash
mariadb -t -e "SELECT id, worker, client_ip, path, created_at FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 5;"
mariadb -t -e "SELECT worker, COUNT(*) AS total FROM db_shibuya_K50.request_logs GROUP BY worker;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/48847c61-a18c-42c1-ae77-b19c8a8475b9" />

**inumaki**

```bash
mariadb -t -e "SELECT id, worker, client_ip, path FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 5;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/1e9db6a6-25b5-4e0f-8d65-c8f6580939a5" />

#### Cek autostart

**maki, panda, nanami, todo, kirara**

```bash
cat /root/boot.d/*.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/afe7cc0a-43bc-4ceb-803b-3d92a627561d" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/ae422b2e-c993-4414-a15c-f8395c56f55c" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/6e331bf8-3255-4d19-8b18-7461172f49a8" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/f8a3adeb-4c03-4438-9910-e4ad62ebf100" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/922fa0c3-ae1d-43d7-b396-61a71b85b054" />

----

### Soal 15:
> Geto bertugas mengendalikan pembagian beban request API di internal Data Center agar server tidak tumbang bersamaan. Konfigurasikan Nginx pada geto sebagai Load Balancer internal dengan upstream api_cluster yang mengarahkan trafik ke nanami dan todo. Terapkan algoritma Weighted Round Robin dengan bobot 3:1, di mana nanami menerima porsi beban tiga kali lebih banyak daripada todo. Buktikan distribusi beban ini dengan melakukan loop request berulang kali ke geto dari jaringan lokal Data Center dan periksa rasio responnya.

#### Cek kesiapan

**geto**

```bash
ip -br a show eth0
ip route | grep default
nginx -v
for h in 192.236.4.5 192.236.4.6; do echo -n "$h : "; curl -s -H "Host: jujutsu.K50.com" http://$h/api; echo; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/eef15720-1aab-4d58-8b5f-dcf1b8d35a18" />

#### Konfigurasi Load Balancer

**geto**

```bash
cat > /root/setup-geto.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-geto.sh - Internal Load Balancer (nginx): upstream api_cluster, WRR 3:1
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
SETUP_EOF

bash -n /root/setup-geto.sh && echo "script OK" && bash /root/setup-geto.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/849bbdf1-4b09-4840-9a32-9cede52ddbc8" />

#### Uji satu request (lokal di geto)

**geto**

```bash
curl -s -i http://127.0.0.1/api
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9742ab76-186a-4690-bd30-5aa684370a50" />

#### Buktikan rasio 3:1 dari jaringan Data Center

**maki, lihat pola urutan (8 request)**

```bash
for i in $(seq 1 8); do curl -s http://192.236.4.2/api | grep -o '"worker":"[a-z]*"'; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/639a2a8b-0297-4065-ba27-98dd316cce3f" />

**maki, hitung rasio (100 request)**

```bash
for i in $(seq 1 100); do curl -s http://192.236.4.2/api | grep -o '"worker":"[a-z]*"'; done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/02df05e0-5952-42c4-ae09-0cf88c8d5d37" />

**maki, bukti lewat header X-Upstream**

```bash
for i in $(seq 1 100); do curl -s -D - -o /dev/null http://192.236.4.2/api | grep -i '^x-upstream'; done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d4abd900-2e86-4729-a1db-4865d84d1c70" />


#### Konfirmasi dari sisi database (bukti independen)

**yaga**

```bash
mariadb -t -e "SELECT worker, COUNT(*) AS total FROM (SELECT worker FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 100) t GROUP BY worker;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/3103ce08-42bf-4d19-a211-d5c92fd1bcef" />

#### Cek autostart

**geto**

```bash
cat /root/boot.d/nginx.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a98805fd-0d90-434c-8bfb-d3e792eab1fc" />



----

### Soal 16:
> Gojo berdiri di perbatasan DMZ sebagai gerbang publik tunggal bagi seluruh client dari luar maupun dalam. Konfigurasikan Nginx pada gojo untuk melayani domain jujutsu.<xxxx>.com dan www.jujutsu.<xxxx>.com menggunakan metode Path-Based Routing. Atur agar request root (/) diteruskan secara Round Robin ke worker frontend (maki dan panda), sedangkan request ke path /api diteruskan langsung ke geto. Uji dari client Divisi A atau B bahwa akses ke web utama dibalas oleh Maki/Panda, sedangkan akses ke /api diteruskan dan dijawab oleh Nanami/Todo.

#### Cek kesiapan jalur gojo ke backend

**gojo**

```bash
ip -br a show eth0
ip route | grep default
nginx -v
echo "== maki";  curl -s -H "Host: jujutsu.K50.com" http://192.236.4.3/
echo "== panda"; curl -s -H "Host: jujutsu.K50.com" http://192.236.4.4/
echo "== geto";  curl -s -i http://192.236.4.2/api | egrep -i 'HTTP/|x-upstream|worker'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a9e01096-6d98-404b-980d-8a436e023d03" />

#### Konfigurasi Nginx di gojo

**gojo**

```bash
cat > /root/setup-gojo.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-gojo.sh - Public Reverse Proxy (nginx): path-based routing
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
SETUP_EOF

bash -n /root/setup-gojo.sh && echo "script OK" && bash /root/setup-gojo.sh```
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/29c1f1bd-39d1-451d-8ddd-8a3261e485a6" />

#### Uji lokal di gojo

**gojo**

```bash
echo "=== ROOT (/) ==="
curl -s -D - http://127.0.0.1/ | egrep -i 'HTTP/|x-gojo|Worker'
echo "=== /api ==="
curl -s -D - http://127.0.0.1/api | egrep -i 'HTTP/|x-gojo|x-upstream|worker'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/99c005f5-acb7-4475-9331-0187cc8463e0" />

#### Cek resolusi DNS dari client

**itadori**

```bash
cat /etc/resolv.conf
dig +short jujutsu.K50.com
dig +short www.jujutsu.K50.com
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/1f79ddf2-f3ec-4da9-874f-177322ed8644" />

#### Uji Round Robin root (/) dari client

**itadori**

```bash
for i in $(seq 1 6); do curl -s http://jujutsu.K50.com/ | grep Worker; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/36985185-78ea-42b4-9979-c87b5d9637d9" />

Hitung rasio

```bash
for i in $(seq 1 100); do curl -s http://jujutsu.K50.com/ | grep -o 'Worker: [a-z]*'; done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/8d1b81ce-e135-4028-9bf3-95dda4a5f63a" />

#### Uji /api lewat gojo dari client

**itadori**

```bash
curl -s -D - http://jujutsu.K50.com/api | egrep -i 'HTTP/|x-gojo|x-upstream|worker'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/96b827cd-91e7-44ee-a631-eeca63c5f587" />

Hitung distribusi (diteruskan ke geto, jadi 3:1 tetap berlaku)

```bash
for i in $(seq 1 40); do curl -s http://jujutsu.K50.com/api | grep -o '"worker":"[a-z]*"'; done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/53ef0de9-30ce-4eb5-be19-9f5983285449" />

#### Uji dari client Divisi B dan domain www

**kusakabe**

```bash
echo "--- www root:"
curl -s http://www.jujutsu.K50.com/ | grep Worker
echo "--- www api:"
curl -s http://www.jujutsu.K50.com/api | grep -o '"worker":"[a-z]*"'
echo "--- 4 request root:"
for i in 1 2 3 4; do curl -s http://jujutsu.K50.com/ | grep -o 'Worker: [a-z]*'; done
echo "--- 4 request api:"
for i in 1 2 3 4; do curl -s http://jujutsu.K50.com/api | grep -o '"worker":"[a-z]*"'; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9f21bec2-5f4d-4303-a312-826fbd33b037" />

#### Bukti gojo adalah gerbang tunggal

**itadori**

```bash
echo -n "via gojo        -> / : "; curl -s -o /dev/null -w "%{http_code}\n" http://jujutsu.K50.com/
echo -n "langsung maki   -> / : "; curl -s -o /dev/null -w "%{http_code}\n" http://192.236.4.3/
echo -n "langsung nanami -> /api : "; curl -s -o /dev/null -w "%{http_code}\n" http://192.236.4.5/api
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/20cb00fd-1af6-4a52-9bd1-fe31c88dd81e" />

#### Bukti dari sisi worker (source IP = gojo)

**maki**

```bash
tail -n 4 /var/log/nginx/access.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/f87f1623-1441-4ef6-92bd-23ddc5fd112c" />

**yaga**

```bash
mariadb -t -e "SELECT id, worker, client_ip, path FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 5;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9aa1f1c1-6bf7-4a71-a1d2-0de6bc84a0a6" />

#### Cek autostart

**gojo**

```bash
cat /root/boot.d/nginx.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/50d2e517-c8fc-4a31-92b1-cc9e190f9a7c" />

----

### Soal 17:
> Komando pusat perlu mengetahui IP asli klien yang mengirimkan request tanpa tertukar dengan IP proxy perantara. Konfigurasikan gojo dan geto agar meneruskan informasi alamat klien melalui header X-Real-IP dan X-Forwarded-For. Pastikan geto hanya mempercayai informasi alamat klien yang diterima dari proxy terpercaya, dan skrip API menyimpan alamat klien yang telah diverifikasi ke kolom client_ip pada tabel request_logs di database yaga. Uji dengan mengirimkan request dari klien Network 2 dan Network 3 ke endpoint /api, kemudian periksa database untuk memastikan alamat yang tercatat sesuai dengan IP klien asal, bukan IP gojo atau geto.

#### Worker API menyimpan IP klien terverifikasi

**nanami, todo, kirara**

```bash
cat > /root/setup-api-17.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-api-17.sh - Soal 17: worker API mencatat IP klien terverifikasi
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
SETUP_EOF

bash -n /root/setup-api-17.sh && echo "script OK" && bash /root/setup-api-17.sh
````

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/35d953d4-2064-457b-9c9a-ebcb29cd48f3" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/b0135201-a328-4c27-8ad0-3bdacb16bc20" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a3984a3d-cab8-48eb-bceb-1ccabd7281c1" />

#### geto hanya percaya pada gojo

**geto**

```bash
cat > /root/setup-geto-17.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-geto-17.sh - Soal 17: LB teruskan IP klien, hanya percaya gojo
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
SETUP_EOF

bash -n /root/setup-geto-17.sh && echo "script OK" && bash /root/setup-geto-17.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/10ff3b7f-c78d-4488-bfc3-481715de9c01" />

#### gojo meneruskan IP klien

**gojo**

```bash
cat > /root/setup-gojo-17.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-gojo-17.sh - Soal 17: gojo kirim X-Real-IP dan X-Forwarded-For
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
SETUP_EOF

bash -n /root/setup-gojo-17.sh && echo "script OK" && bash /root/setup-gojo-17.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/4f5409d3-f1ac-459a-99dc-77ba20d6d85f" />

#### Uji dari klien Network 2 dan Network 3

**Klien Network 2: itadori**

```bash
MYIP=$(ip -4 -br a show eth0 | awk '{print $3}' | cut -d/ -f1)
echo "IP itadori : $MYIP"
for i in 1 2 3 4; do curl -s http://jujutsu.K50.com/api; echo; done
curl -s -D - -o /dev/null http://jujutsu.K50.com/api | egrep -i 'HTTP/|x-gojo|x-upstream|x-client-seen'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/c0f75212-59ad-40be-9490-39d1ff889e9a" />

client_ip kini IP itadori, sedangkan peer_ip tetap IP geto. Itu menunjukkan IP klien tidak tertukar dengan IP proxy.

**Klien Network 3: kusakabe**

```bash
MYIP=$(ip -4 -br a show eth0 | awk '{print $3}' | cut -d/ -f1)
echo "IP kusakabe : $MYIP"
for i in 1 2 3 4; do curl -s http://jujutsu.K50.com/api; echo; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/612b742b-1d5c-41e7-aef1-9334628c94eb" />

#### Uji anti-spoof

**Klien memalsukan header lewat gojo: itadori**

```bash
echo "IP itadori : $(ip -4 -br a show eth0 | awk '{print $3}' | cut -d/ -f1)"
curl -s -H "X-Real-IP: 1.2.3.4" -H "X-Forwarded-For: 1.2.3.4" http://jujutsu.K50.com/api; echo
```

**Node tak terpercaya menembak geto langsung: maki**

```bash
curl -s -H "X-Real-IP: 1.2.3.4" -H "X-Forwarded-For: 1.2.3.4" http://192.236.4.2/api; echo
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/739c27c0-ed65-4bea-bc83-b35490e8aa23" />

#### Bukti dari log nginx

**gojo**

```bash
tail -n 6 /var/log/nginx/gojo-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/3613bcbd-ac3d-473b-ac2b-cd3e35232af8" />

**geto**

```bash
tail -n 6 /var/log/nginx/geto-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/1a7cd8b7-1a26-4912-8925-fa5317751d26" />

**nanami**

```bash
tail -n 4 /var/log/nginx/api-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/75be3d9b-6f9f-46ae-a6bf-1219f3862787" />

#### Periksa database

**yaga**

```bash
mariadb -t -e "SELECT id, worker, client_ip, path, created_at FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 12;"
mariadb -t -e "SELECT client_ip, COUNT(*) AS total FROM db_shibuya_K50.request_logs GROUP BY client_ip;"
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/46aaab4f-23b0-45ae-9a5e-952c9d7acbb5" />

**inumaki** bukti replikasi

```bash
mariadb -t -e "SELECT client_ip, COUNT(*) AS total FROM db_shibuya_K50.request_logs GROUP BY client_ip;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/90dcde47-fe44-4ec5-8805-d33f24328942" />

#### Cek autostart

**gojo, geto, nanami, todo, kirara**

```bash
cat /root/boot.d/*.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/01d06ba0-d5f2-41de-8a91-d6c0e8555d1f" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/4b411db1-ede1-4d8c-8010-7ce6dc48149a" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/0a2a165f-34ff-4ee6-8169-82c2ee716986" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d4fa2e68-9f74-42cd-b02e-fa10c4628cf4" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/6fba0a97-aae9-4bfc-b4da-1a6e90fac6a0" />

----

### Soal 18:
> nanami dan todo merupakan worker API utama, sedangkan kirara disiapkan sebagai worker cadangan. Konfigurasikan upstream api_cluster pada geto agar kirara menjadi server backup, serta terapkan passive health check dengan parameter max_fails=2 dan fail_timeout=5s pada worker API utama. Pastikan kirara menjalankan layanan API yang kompatibel dengan endpoint utama. Simulasikan gangguan dengan menghentikan layanan Nginx atau layanan API pada nanami dan todo. Buktikan dari klien bahwa request ke /api dialihkan ke kirara dan menghasilkan respons API yang valid tanpa error 502 Bad Gateway.

#### Cek kesiapan kirara

**geto**

```bash
for h in 192.236.4.5 192.236.4.6 192.236.4.7; do echo -n "$h : "; curl -s -H "Host: jujutsu.K50.com" http://$h/api; echo; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d1feeec6-9cd9-40a1-9ad1-ab5fbcb5f83e" />

#### Konfigurasi geto

**geto**

```bash
cat > /root/setup-geto-18.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-geto-18.sh - Soal 18: kirara backup + passive health check
# (konfigurasi soal 15 dan 17 dipertahankan)
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
SETUP_EOF

bash -n /root/setup-geto-18.sh && echo "script OK" && bash /root/setup-geto-18.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/f98ee5a5-3974-42b6-a54a-a41c9d893fe7" />

#### Baseline (semua worker hidup)

**itadori**

```bash
for i in $(seq 1 20); do
  C=$(curl -s -o /tmp/r.json -w "%{http_code}" http://jujutsu.K50.com/api)
  echo "$C $(grep -o '"worker":"[a-z]*"' /tmp/r.json)"
done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/63645348-e3b1-43b9-9cb1-93fb57bbc8fc" />

#### Gangguan 1, hanya nanami mati

**nanami**

```bash
service nginx stop
pgrep -a nginx || echo "nginx nanami mati"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/34c93a0c-00f5-4111-bac8-d98d824c1766" />

**geto**

```bash
curl -s -o /dev/null -w "nanami langsung : %{http_code}\n" -H "Host: jujutsu.K50.com" http://192.236.4.5/api
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/99c0499b-4251-4d1f-8a6a-b12bff781de7" />

**itadori**

```bash
for i in $(seq 1 20); do
  C=$(curl -s -o /tmp/r.json -w "%{http_code}" http://jujutsu.K50.com/api)
  echo "$C $(grep -o '"worker":"[a-z]*"' /tmp/r.json)"
done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/4e96dbef-1f29-4d7a-8d82-f4604fe5c977" />

#### Gangguan 2, nanami dan todo mati (bukti utama)

**todo**

```bash
service nginx stop
pgrep -a nginx || echo "nginx todo mati"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/89ce74b4-5c39-4b04-87eb-8725789f42a9" />

**itadori**

Satu request dengan header lengkap

```bash
curl -s -D - http://jujutsu.K50.com/api | egrep -i 'HTTP/|x-gojo|x-upstream|x-client-seen|status|worker'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/3afa5d5d-0c29-4012-bd3b-0b15d47a90c1" />

Beban beruntun

```bash
for i in $(seq 1 20); do
  C=$(curl -s -o /tmp/r.json -w "%{http_code}" http://jujutsu.K50.com/api)
  echo "$C $(grep -o '"worker":"[a-z]*"' /tmp/r.json)"
done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/5c07eb2e-fca0-4e6c-9215-b509c1250e3f" />

Dari klien Network 3 (kusakabe)

```bash
for i in 1 2 3 4 5; do curl -s -o /dev/null -w "%{http_code} " http://jujutsu.K50.com/api; done; echo
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/88d6df0a-630b-4871-ad42-e201e947bcdd" />

#### Bukti dari log geto dan database

**geto**

```bash
grep -c 'ups=' /var/log/nginx/geto-realip.log
tail -n 6 /var/log/nginx/geto-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d47084bc-e61e-4bb3-8339-cd526c98ddba" />

**kirara**

```bash
tail -n 4 /var/log/nginx/api-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/09620e05-8f43-406a-abb1-c5a5c4106a03" />

**yaga**

```bash
mariadb -t -e "SELECT id, worker, client_ip, path FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 10;"
mariadb -t -e "SELECT worker, client_ip, COUNT(*) AS total FROM db_shibuya_K50.request_logs GROUP BY worker, client_ip;"
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/e038177d-6e0e-4173-bc4c-508d711a2554" />

#### Pemulihan

**nanami dan todo**

```bash
service nginx start
sleep 1
pgrep -a nginx | head -2
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/24d652fc-2bcc-4c5e-bd2c-cd795b3e7635" />
<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/64463ec5-5dc8-4f48-ac7b-5e70d0a0abdb" />

**itadori**

```bash
sleep 6
for i in $(seq 1 20); do
  C=$(curl -s -o /tmp/r.json -w "%{http_code}" http://jujutsu.K50.com/api)
  echo "$C $(grep -o '"worker":"[a-z]*"' /tmp/r.json)"
done | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/51b94052-888f-475d-8cbd-8b12a4babad6" />

----

### Soal 19:
> gojo bertugas mengoptimalkan layanan web sekaligus membatasi request berlebihan. Konfigurasikan Nginx Proxy Caching untuk halaman web frontend dengan masa berlaku cache 10 menit dan tambahkan header X-Cache-Status. Terapkan rate limiting pada path /api dengan batas 10 request per detik per IP klien. Buktikan bahwa request ke halaman web yang memenuhi syarat cache menghasilkan status MISS pada akses awal dan HIT pada akses berikutnya. Uji rate limiting secara terpisah dengan mengirimkan request beruntun ke /api, kemudian catat status respons yang dihasilkan ketika batas terlampaui.

#### Konfigurasi gojo

**gojo**

```bash
cat > /root/setup-gojo-19.sh << 'SETUP_EOF'
#!/bin/bash
# /root/setup-gojo-19.sh - Soal 19: proxy cache (/) + rate limiting (/api)
# (konfigurasi soal 16 dan 17 dipertahankan)
MAKI="192.236.4.3"
PANDA="192.236.4.4"
GETO="192.236.4.2"

mkdir -p /var/cache/nginx/frontend
chown -R www-data:www-data /var/cache/nginx

rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/jujutsu-proxy
cat > /etc/nginx/sites-available/jujutsu-proxy <<'NGEOF'
# Cache halaman frontend: valid 10 menit
proxy_cache_path /var/cache/nginx/frontend levels=1:2 keys_zone=frontend_cache:10m max_size=100m inactive=10m use_temp_path=off;

# Rate limit: 10 request/detik per IP klien
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

upstream frontend_cluster {
    zone frontend_cluster 64k;
    server __MAKI__;
    server __PANDA__;
}

upstream geto_lb {
    server __GETO__;
}

log_format gojo_realip '$remote_addr xff="$http_x_forwarded_for" up=$upstream_addr cache=$upstream_cache_status lim=$limit_req_status rt=$request_time "$request" $status';

server {
    listen 80 default_server;
    server_name jujutsu.K50.com www.jujutsu.K50.com;
    access_log /var/log/nginx/gojo-realip.log gojo_realip;

    # Frontend: Round Robin + cache 10 menit
    location / {
        proxy_pass http://frontend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_cache frontend_cache;
        proxy_cache_key "$scheme$host$request_uri";
        proxy_cache_valid 200 10m;

        add_header X-Cache-Status $upstream_cache_status always;
        add_header X-Gojo-Upstream $upstream_addr always;
    }

    # API: rate limit, tanpa cache
    location /api {
        limit_req zone=api_limit burst=5 nodelay;
        limit_req_status 429;

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
grep -nE 'proxy_cache_path|proxy_cache_valid|X-Cache-Status|limit_req' /etc/nginx/sites-available/jujutsu-proxy
ls -ld /var/cache/nginx/frontend
SETUP_EOF

bash -n /root/setup-gojo-19.sh && echo "script OK" && bash /root/setup-gojo-19.sh
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/f783a14a-ce06-4072-9468-98ea3750d177" />

#### Bukti cache, MISS lalu HIT

**itadori**

```bash
for i in 1 2 3 4; do
  echo "--- request $i"
  curl -s -D - -o /dev/null "http://jujutsu.K50.com/?uji=19a" | egrep -i 'HTTP/|x-cache-status|x-gojo-upstream'
done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/ed4496f7-8734-42cf-ba42-5f25c7fab67f" />

Konten yang sama selama masa cache

```bash
for i in 1 2 3 4; do curl -s "http://jujutsu.K50.com/?uji=19a" | grep Worker; done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/09f7ba7c-7421-43ff-8f0e-b4623604dbd7" />

URL berbeda memicu MISS baru (Round Robin maki/panda tetap berjalan di balik cache)

```bash
for u in 19b 19c 19d 19e; do
  echo -n "$u -> "; curl -s -D - -o /dev/null "http://jujutsu.K50.com/?uji=$u" | egrep -i 'x-cache-status|x-gojo-upstream' | tr '\r\n' '  '; echo
done
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/6656f0b8-e3fc-4d0c-8336-b6f4fdfb4e42" />

#### Cache dipakai bersama antar klien

**kusakabe**

```bash
curl -s -D - -o /dev/null "http://jujutsu.K50.com/?uji=19a" | egrep -i 'HTTP/|x-cache-status'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a5475219-4ecb-4bcb-a8e3-94fc137f6ec4" />

#### Bukti di sisi gojo

**gojo**

```bash
ls -R /var/cache/nginx/frontend | head -8
du -sh /var/cache/nginx/frontend
grep 'uji=19a' /var/log/nginx/gojo-realip.log | tail -5
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/66ab5200-8857-46b2-ab19-39f6bb31aa87" />

#### Bukti rate limiting di /api

Hitung baris database sebelum uji

**yaga**

```bash
mariadb -t -e "SELECT COUNT(*) AS sebelum FROM db_shibuya_K50.request_logs;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/6d2b7915-5eed-4995-b7bf-ec962d1c663f" />

#### Request beruntun

**itadori**

```bash
curl -s -o /dev/null -w "%{http_code}\n" "http://jujutsu.K50.com/api?n=[1-30]" | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/42eda545-d575-4fd0-8067-945901dac0be" />

Detail respons saat batas terlampaui

```bash
curl -s -i "http://jujutsu.K50.com/api?n=[1-15]" | grep '^HTTP/'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/3fe785ae-ee6c-47b1-95e5-4c1b948d9b01" />

Kecepatan wajar tetap diterima

```bash
for i in 1 2 3 4 5; do curl -s -o /dev/null -w "%{http_code} " http://jujutsu.K50.com/api; sleep 1; done; echo
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/7b686ad1-cb9a-42e7-adb4-edd769d4c8cc" />

Bukti dari sisi gojo dan database

**gojo**

```bash
awk '{print $NF}' /var/log/nginx/gojo-realip.log | sort | uniq -c
grep -c 'lim=REJECTED' /var/log/nginx/gojo-realip.log
grep 'lim=REJECTED' /var/log/nginx/gojo-realip.log | tail -2
grep 'limiting requests' /var/log/nginx/error.log | tail -2
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/89290cd6-908f-4564-a3e8-ff43b0a7fcf0" />

Request yang ditolak punya up=-, artinya tidak diteruskan ke geto.

**yaga**

```bash
mariadb -t -e "SELECT COUNT(*) AS sesudah FROM db_shibuya_K50.request_logs;"
mariadb -t -e "SELECT id, worker, client_ip, path FROM db_shibuya_K50.request_logs ORDER BY id DESC LIMIT 5;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/239d81b4-e648-4ef1-9d53-1573027c8bc8" />

----

### Soal 20:
> Sebelum Curtain di Shibuya resmi dibuka, Kusakabe memimpin audit untuk menguji kapasitas layanan. Dari terminal kusakabe, jalankan benchmark menggunakan Apache Benchmark dengan parameter -n 600 -c 30 menuju http://jujutsu.<xxxx>.com/. Catat Requests per Second (RPS), latensi, dan jumlah request yang gagal. Lakukan pengujian tambahan pada endpoint /api untuk mengamati efek rate limiting. Bandingkan hasil pengujian baseline dengan hasil ketika rate limiting aktif, serta gunakan access log gojo untuk membedakan kegagalan aplikasi, koneksi, dan request yang ditolak oleh kebijakan rate limit.

#### Cek kesiapan

**kusakabe**

```bash
ip -4 -br a show eth0
cat /etc/resolv.conf
dig +short jujutsu.K50.com
ab -V | head -1
curl -s -o /dev/null -w "%{http_code}\n" http://jujutsu.K50.com/
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/f8511363-405f-4a62-b5f6-f20912aac3a6" />

**gojo**

```bash
pgrep -a nginx | head -2
grep -nE 'proxy_cache_valid|limit_req' /etc/nginx/sites-available/jujutsu-proxy
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/c7ee8891-7d00-4e06-ba1a-184fc732a592" />

**gojo**

```bash
cp /var/log/nginx/gojo-realip.log /root/gojo-realip.soal19.bak
ls -l /root/gojo-realip.soal19.bak
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/1a91880d-f79c-4b5b-9dbf-87d3002ec503" />

#### Baseline halaman web / (cache aktif)

**gojo**

```bash
: > /var/log/nginx/gojo-realip.log
wc -l < /var/log/nginx/gojo-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a87952f7-6398-4f05-8cd4-abc4daf16779" />

**kusakabe**

```bash
ab -n 600 -c 30 http://jujutsu.K50.com/ | tee /tmp/ab-1-root.txt
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/a62fb46d-5524-48aa-a17c-3a5fa07c28d7" />

**kusakabe**

```bash
egrep 'Concurrency Level|Time taken|Complete requests|Failed requests|Connect:|Non-2xx|Requests per second|Time per request|Total:|50%|95%|99%|100%' /tmp/ab-1-root.txt
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a4f6d581-289f-44f9-ba70-b7f05c39ae40" />

**gojo**

```bash
LOG=/var/log/nginx/gojo-realip.log
echo "Total baris log : $(wc -l < $LOG)"
echo "--- status:";   awk '{print $NF}' $LOG | sort | uniq -c
echo "--- cache:";    grep -o 'cache=[A-Z-]*' $LOG | sort | uniq -c
echo "--- upstream:"; grep -o 'up=[^ ]*' $LOG | sort | uniq -c
awk -F'rt=' '{split($2,a," "); s+=a[1]; n++} END{printf "rata-rata rt gojo: %.4f detik (%d request)\n", s/n, n}' $LOG
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/1e463090-260e-422b-b23a-ff09dd1d35de" />

#### /api dengan rate limiting ON

**yaga**

```bash
mariadb -N -e "SELECT COUNT(*) FROM db_shibuya_K50.request_logs;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/4806e9f6-d3cb-4f12-b026-b34ca60c3d7c" />

**gojo**

```bash
: > /var/log/nginx/gojo-realip.log
: > /var/log/nginx/error.log
wc -l < /var/log/nginx/gojo-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9d157bcb-6036-4afc-803b-af91d7e63bda" />

**kusakabe**

```bash
ab -n 600 -c 30 http://jujutsu.K50.com/api | tee /tmp/ab-2-api-limit-on.txt
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/2fecb9d9-4c76-4b3f-b36e-8b8d47b94dde" />

**kusakabe**

```bash
egrep 'Concurrency Level|Time taken|Complete requests|Failed requests|Connect:|Non-2xx|Requests per second|Time per request|Total:|50%|95%|99%|100%' /tmp/ab-2-api-limit-on.txt
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/fc85b381-2258-48f6-9d64-488661f7cc92" />

**gojo**

```bash
LOG=/var/log/nginx/gojo-realip.log
echo "Total baris log     : $(wc -l < $LOG)"
echo "--- status:"; awk '{print $NF}' $LOG | sort | uniq -c
echo "lim=PASSED          : $(grep -c 'lim=PASSED' $LOG)"
echo "lim=REJECTED        : $(grep -c 'lim=REJECTED' $LOG)"
echo "--- contoh lolos:";   grep 'lim=PASSED' $LOG | head -2
echo "--- contoh ditolak:"; grep 'lim=REJECTED' $LOG | head -2
echo "error.log 'limiting requests': $(grep -c 'limiting requests' /var/log/nginx/error.log)"
grep 'limiting requests' /var/log/nginx/error.log | tail -1
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/d1da7728-3566-4e9d-87e3-c9013f5b8574" />

**yaga**

```bash
mariadb -N -e "SELECT COUNT(*) FROM db_shibuya_K50.request_logs;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/9ada1752-083d-4509-b327-758d71aa02e4" />

**kusakabe**

```bash
ab -l -n 600 -c 30 http://jujutsu.K50.com/api | egrep 'Failed requests|Non-2xx'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/66993c0e-a40c-4201-8bb6-94d5462068e4" />

#### Baseline /api tanpa rate limit

**gojo**

```bash
sed -i 's/^\(\s*\)limit_req zone=/\1#limit_req zone=/' /etc/nginx/sites-available/jujutsu-proxy
grep -n 'limit_req' /etc/nginx/sites-available/jujutsu-proxy
nginx -t && nginx -s reload
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/2c5ff471-79ef-49ee-80ed-8dfb852c2817" />

**gojo**

```bash
: > /var/log/nginx/gojo-realip.log
wc -l < /var/log/nginx/gojo-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/5451148e-9e62-4c17-a459-943a42f7d8f0" />

**yaga**

```bash
mariadb -N -e "SELECT COUNT(*) FROM db_shibuya_K50.request_logs;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/de985d9e-abed-40e7-9f26-65492bd69ecf" />

**kusakabe**

```bash
ab -n 600 -c 30 http://jujutsu.K50.com/api | tee /tmp/ab-3-api-limit-off.txt
```

<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/9d3d17a5-6e3a-4fed-93a8-43591113a48e" />

**kusakabe**

```bash
egrep 'Concurrency Level|Time taken|Complete requests|Failed requests|Connect:|Non-2xx|Requests per second|Time per request|Total:|50%|95%|99%|100%' /tmp/ab-3-api-limit-off.txt
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/6e5b1d01-3e7f-486d-94b4-dae08b649781" />

**gojo**

```bash
LOG=/var/log/nginx/gojo-realip.log
echo "Total baris log : $(wc -l < $LOG)"
echo "--- status:";   awk '{print $NF}' $LOG | sort | uniq -c
echo "--- limit:";    grep -o 'lim=[A-Z-]*' $LOG | sort | uniq -c
echo "--- upstream:"; grep -o 'up=[^ ]*' $LOG | sort | uniq -c
awk -F'rt=' '{split($2,a," "); s+=a[1]; n++} END{printf "rata-rata rt gojo: %.4f detik (%d request)\n", s/n, n}' $LOG
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/5077e18a-0eef-4861-a260-a000698783f3" />

**yaga**

```bash
mariadb -N -e "SELECT COUNT(*) FROM db_shibuya_K50.request_logs;"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/292a3ea9-89f4-4884-a1a0-26265fc42f80" />

#### Nyalakan lagi rate limit (wajib)

**gojo**

```bash
sed -i 's/^\(\s*\)#limit_req zone=/\1limit_req zone=/' /etc/nginx/sites-available/jujutsu-proxy
grep -n 'limit_req' /etc/nginx/sites-available/jujutsu-proxy
nginx -t && nginx -s reload
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/49f8bbdd-52e4-425e-bb44-1c65470a7db7" />

**kusakabe**

```bash
curl -s -o /dev/null -w "%{http_code}\n" "http://jujutsu.K50.com/api?n=[1-30]" | sort | uniq -c
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/3a209c6d-3479-4f44-ba86-9ac14fb41505" />

#### Simulasi gangguan untuk membedakan jenis kegagalan

Kegagalan aplikasi/upstream (5xx)

**gojo**

```bash
: > /var/log/nginx/gojo-realip.log
wc -l < /var/log/nginx/gojo-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/962f4642-2c0a-45b8-a26e-5ef6425498fa" />

**geto**

```bash
service nginx stop
pgrep -a nginx || echo "nginx geto mati"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/90f8bd91-7963-406d-a67c-f4af046d41f0" />

**kusakabe**

```bash
ab -n 100 -c 10 http://jujutsu.K50.com/api | egrep 'Complete requests|Failed requests|Non-2xx|Requests per second'
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/b88a97e4-2cd8-4248-9672-287d46ee573a" />

**gojo**

```bash
LOG=/var/log/nginx/gojo-realip.log
echo "--- status:"; awk '{print $NF}' $LOG | sort | uniq -c
echo "--- 502 (kegagalan upstream):"; grep ' 502$' $LOG | head -2
echo "--- 429 (rate limit):";         grep ' 429$' $LOG | head -2
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/111ac949-864d-45a6-9f9d-1abd3fcce9ec" />

**geto**

```bash
service nginx start
sleep 1
pgrep -a nginx | head -2
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/0fadcbbe-88fd-4210-b4b1-f43fda0516c0" />

#### Kegagalan koneksi (request tidak pernah sampai ke gojo)

**gojo**

```bash
: > /var/log/nginx/gojo-realip.log
service nginx stop
pgrep -a nginx || echo "nginx gojo mati"
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/f45ac702-f489-41b6-aa9d-acfe002451ae" />

**kusakabe**

```bash
ab -n 20 -c 2 http://jujutsu.K50.com/api
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/c1e573d9-0346-4eae-a672-a8e8a25e2934" />

**gojo**

```bash
service nginx start
sleep 1
pgrep -a nginx | head -2
wc -l < /var/log/nginx/gojo-realip.log
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/e0ef6302-c00e-4db6-81a9-b70e0e9908eb" />

**kusakabe**

```bash
curl -s -o /dev/null -w "web : %{http_code}\n" http://jujutsu.K50.com/
sleep 3
curl -s -o /dev/null -w "api : %{http_code}\n" http://jujutsu.K50.com/api
```

<img width="745" height="521" alt="image" src="https://github.com/user-attachments/assets/a786644b-b67d-412f-a4f1-759b0ba65efc" />

----

## Daftar Script

| Soal | Node           | File                                                                                                   |
| ---- | -------------- | ------------------------------------------------------------------------------------------------------ |
| 1    | jichi          | [soal01-jichi.sh](script/soal01/soal01-jichi.sh), [interfaces/](script/soal01/interfaces/)             |
| 2    | tengen         | [soal02-tengen.sh](script/soal02/soal02-tengen.sh)                                                     |
| 3    | jichi, client  | [soal03-jichi.sh](script/soal03/soal03-jichi.sh), [interfaces-client](script/soal03/interfaces-client) |
| 4    | tengen         | [soal04-tengen.sh](script/soal04/soal04-tengen.sh)                                                     |
| 5    | tengen         | [soal05-tengen.sh](script/soal05/soal05-tengen.sh)                                                     |
| 6    | tengen         | [soal06-tengen.sh](script/soal06/soal06-tengen.sh)                                                     |
| 7    | tengen, client | [soal07-tengen.sh](script/soal07/soal07-tengen.sh), [soal07-client.sh](script/soal07/soal07-client.sh) |
| 8    | tengen         | [soal08-tengen.sh](script/soal08/soal08-tengen.sh)                                                     |
| 9    | jichi, client  | [soal09-jichi.sh](script/soal09/soal09-jichi.sh), [soal09-client.sh](script/soal09/soal09-client.sh)   |
| 10   | tengen, jichi  | [init-tengen.sh](script/soal10/init-tengen.sh), [init-jichi.sh](script/soal10/init-jichi.sh)           |

Script tengen untuk soal 2, 4, 5, dan 6 masing-masing menulis ulang `dhcpd.conf` secara utuh dan bertahap. Konfigurasi final ada di script soal 6, dan script itulah yang dipanggil `init.sh` saat boot.
