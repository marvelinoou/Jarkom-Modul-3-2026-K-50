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

----

### Soal 12:
> Peta domain harus memetakan pintu masuk utama dan tetap bisa mencari alamat di luar kawasan Shibuya. Pada utahime, buat A record jujutsu.<xxxx>.com yang mengarah ke gojo, serta CNAME www yang merujuk ke domain utama tersebut. Buat pula Reverse DNS (zona PTR) untuk melacak IP gojo kembali ke domain resminya, dan aktifkan fitur DNS Forwarder pada BIND9 mengarah ke IP gateway internet (192.168.122.1). Uji dari client dengan dig untuk mengecek CNAME, PTR, dan buktikan client tetap bisa melakukan ping ke domain internet seperti google.com.

----

### Soal 13:
> Kepala Sekolah Yaga dan Inumaki mendirikan database terpusat yang redundan agar log aktivitas kutukan tetap aman tersimpan. Konfigurasikan MariaDB pada yaga sebagai DB-Master dan inumaki sebagai DB-Slave. Buat database db_shibuya_<xxxx> beserta tabel request_logs di Master, aktifkan binary logging (log-bin, server-id), lalu hubungkan inumaki sebagai Slave yang menyalin data secara realtime dengan CHANGE MASTER TO. Berikan hak akses remote bagi seluruh node di Network 4, lalu buktikan replikasi berhasil dengan memasukkan data baru di Master dan memeriksa hasilnya di Slave.

----

### Soal 14:
> Para penyihir lapangan bersiaga di Data Center sebagai pekerja backend untuk memproses aplikasi. Pasang Nginx dan PHP-FPM pada maki dan panda untuk menyajikan web frontend yang menampilkan hostname masing-masing. Pada nanami, todo, dan kirara, siapkan layanan API yang mencatat log request ke database yaga. Konfigurasikan virtual host agar worker merespons domain layanan yang ditentukan. Batasi akses langsung dari klien ke worker, web worker hanya menerima trafik melalui jalur proxy web yang ditentukan, sedangkan worker API hanya menerima trafik melalui geto. Uji bahwa akses langsung dari klien ditolak, sementara akses melalui reverse proxy tetap berhasil.

----

### Soal 15:
> Geto bertugas mengendalikan pembagian beban request API di internal Data Center agar server tidak tumbang bersamaan. Konfigurasikan Nginx pada geto sebagai Load Balancer internal dengan upstream api_cluster yang mengarahkan trafik ke nanami dan todo. Terapkan algoritma Weighted Round Robin dengan bobot 3:1, di mana nanami menerima porsi beban tiga kali lebih banyak daripada todo. Buktikan distribusi beban ini dengan melakukan loop request berulang kali ke geto dari jaringan lokal Data Center dan periksa rasio responnya.

----

### Soal 16:
> Gojo berdiri di perbatasan DMZ sebagai gerbang publik tunggal bagi seluruh client dari luar maupun dalam. Konfigurasikan Nginx pada gojo untuk melayani domain jujutsu.<xxxx>.com dan www.jujutsu.<xxxx>.com menggunakan metode Path-Based Routing. Atur agar request root (/) diteruskan secara Round Robin ke worker frontend (maki dan panda), sedangkan request ke path /api diteruskan langsung ke geto. Uji dari client Divisi A atau B bahwa akses ke web utama dibalas oleh Maki/Panda, sedangkan akses ke /api diteruskan dan dijawab oleh Nanami/Todo.

----

### Soal 17:
> Komando pusat perlu mengetahui IP asli klien yang mengirimkan request tanpa tertukar dengan IP proxy perantara. Konfigurasikan gojo dan geto agar meneruskan informasi alamat klien melalui header X-Real-IP dan X-Forwarded-For. Pastikan geto hanya mempercayai informasi alamat klien yang diterima dari proxy terpercaya, dan skrip API menyimpan alamat klien yang telah diverifikasi ke kolom client_ip pada tabel request_logs di database yaga. Uji dengan mengirimkan request dari klien Network 2 dan Network 3 ke endpoint /api, kemudian periksa database untuk memastikan alamat yang tercatat sesuai dengan IP klien asal, bukan IP gojo atau geto.

----

### Soal 18:
> nanami dan todo merupakan worker API utama, sedangkan kirara disiapkan sebagai worker cadangan. Konfigurasikan upstream api_cluster pada geto agar kirara menjadi server backup, serta terapkan passive health check dengan parameter max_fails=2 dan fail_timeout=5s pada worker API utama. Pastikan kirara menjalankan layanan API yang kompatibel dengan endpoint utama. Simulasikan gangguan dengan menghentikan layanan Nginx atau layanan API pada nanami dan todo. Buktikan dari klien bahwa request ke /api dialihkan ke kirara dan menghasilkan respons API yang valid tanpa error 502 Bad Gateway.

----

### Soal 19:
> gojo bertugas mengoptimalkan layanan web sekaligus membatasi request berlebihan. Konfigurasikan Nginx Proxy Caching untuk halaman web frontend dengan masa berlaku cache 10 menit dan tambahkan header X-Cache-Status. Terapkan rate limiting pada path /api dengan batas 10 request per detik per IP klien. Buktikan bahwa request ke halaman web yang memenuhi syarat cache menghasilkan status MISS pada akses awal dan HIT pada akses berikutnya. Uji rate limiting secara terpisah dengan mengirimkan request beruntun ke /api, kemudian catat status respons yang dihasilkan ketika batas terlampaui.

----

### Soal 20:
> Sebelum Curtain di Shibuya resmi dibuka, Kusakabe memimpin audit untuk menguji kapasitas layanan. Dari terminal kusakabe, jalankan benchmark menggunakan Apache Benchmark dengan parameter -n 600 -c 30 menuju http://jujutsu.<xxxx>.com/. Catat Requests per Second (RPS), latensi, dan jumlah request yang gagal. Lakukan pengujian tambahan pada endpoint /api untuk mengamati efek rate limiting. Bandingkan hasil pengujian baseline dengan hasil ketika rate limiting aktif, serta gunakan access log gojo untuk membedakan kegagalan aplikasi, koneksi, dan request yang ditolak oleh kebijakan rate limit.

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