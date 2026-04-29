Berikut adalah **README.md** dalam format RAW yang siap Anda copy paste ke GitHub:

```markdown
# WireGuard + WG-UI Production Installer

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passed-brightgreen.svg)](https://www.shellcheck.net/)

Script instalasi otomatis untuk **WireGuard VPN Server** dengan **Web UI** (WireGuard-UI) yang sudah di-FIX untuk masalah database plaintext. Dilengkapi auto-reload, firewall, dan fail2ban.

## ✨ Fitur

- ✅ Instalasi WireGuard + WireGuard-UI (v0.6.2)
- ✅ Fix database **plaintext** (tidak ada error parsing JSON)
- ✅ Auto-reload konfigurasi **tanpa disconnect client**
- ✅ Firewall dengan port blocking (port 5000 hanya localhost)
- ✅ Deteksi otomatis interface utama & MTU
- ✅ Mode **strict firewall** (opsional)
- ✅ **IPv6 disable** (opsional)
- ✅ **Fail2ban** protection (opsional)
- ✅ Credentials disimpan di `/root/wgui_credentials.txt`

## 🚀 Cara Menjalankan Script

### 1. Download Script

```bash
curl -O https://raw.githubusercontent.com/soranewa/wireguardyb/refs/heads/main/WireguardYB.sh
```

Atau jika wget:

```bash
wget https://raw.githubusercontent.com/soranewa/wireguardyb/refs/heads/main/WireguardYB.sh
```

### 2. Jadikan Executable

```bash
chmod +x WireguardYB.sh
```

### 3. Jalankan sebagai Root

```bash
sudo ./WireguardYB.sh
```

### 4. Mode Tambahan (Opsional)

| Parameter | Fungsi |
|-----------|--------|
| `--disable-ipv6` | Nonaktifkan IPv6 di system |
| `--strict-firewall` | Aktifkan strict firewall (hanya SSH, WG, loopback) |
| `--no-fail2ban` | Skip instalasi fail2ban |
| `--reset-db` | Reset database & buat password admin baru |

**Contoh penggunaan:**

```bash
# Install dengan strict firewall dan disable IPv6
./WireguardYB.sh --disable-ipv6 --strict-firewall

# Reset database dan buat password baru
./WireguardYB.sh --reset-db

# Install tanpa fail2ban
./WireguardYB.sh --no-fail2ban
```

## 🔐 Mengakses Web UI

### Via SSH Tunnel (REKOMENDASI)

```bash
ssh -L 5000:127.0.0.1:5000 root@<SERVER_IP>
```

Kemudian buka browser: 👉 **http://localhost:5000**

### Login Credentials

```
Username: admin
Password: (lihat di /root/wgui_credentials.txt)
```

> ⚠️ **PENTING:** Port 5000 hanya bisa diakses dari localhost untuk keamanan. WAJIB menggunakan SSH Tunnel!

## ⚙️ Konfigurasi Setelah Login ke Web UI

### 1. Post-Up Script (WAJIB Diisi)

Setelah login, buka **Settings** → **Server** → masukkan:

**Post-Up Script:**

```bash
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE || iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -C FORWARD -i wg0 -o eth0 -j ACCEPT || iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT; iptables -C FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -C INPUT -i wg0 -j ACCEPT || iptables -A INPUT -i wg0 -j ACCEPT
```

**Pre-Down Script:**

```bash
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null; iptables -D FORWARD -i wg0 -o eth0 -j ACCEPT 2>/dev/null; iptables -D FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
```

> **Catatan:** Ganti `eth0` dengan interface utama server jika berbeda. Cek dengan perintah `ip route | grep default`

### 2. Setting Dasar Lainnya

| Field | Value |
|-------|-------|
| **Endpoint Address** | IP publik server (otomatis terdeteksi) |
| **Endpoint Port** | 51820 |
| **Server Interface Addresses** | `10.252.1.1/24` |
| **Listen Port** | 51820 |
| **MTU** | 1420 (atau 1400 untuk jaringan bermasalah) |

### 3. Membuat Client Baru

1. Klik **"New Client"**
2. Isi nama client (contoh: `laptop-saya`)
3. Biarkan IP auto-assign atau isi manual (`10.252.1.x`)
4. Klik **"Save"**
5. Klik **"Export"** untuk download konfigurasi `.conf`

## 🔧 Tips & Troubleshooting

### Cek Status Service

```bash
systemctl status wg-quick@wg0 wgui wg-autoreload
```

### Cek Log

```bash
# WireGuard
journalctl -u wg-quick@wg0 -f

# WG-UI
journalctl -u wgui -f

# Auto-reload
tail -f /var/log/wg-autoreload.log
```

### Ganti Password Admin

1. Login ke Web UI
2. Klik **Settings** → **Profile**
3. Masukkan password baru
4. **Update juga** file `/root/wgui_credentials.txt`

### Restart WireGuard Tanpa Disconnect Client

```bash
wg syncconf wg0 <(wg-quick strip wg0)
```

Script auto-reload sudah melakukan ini otomatis saat config berubah.

### Backup Konfigurasi

```bash
# Backup database
tar -czf wgui-backup.tar.gz /opt/wireguard-ui/db/

# Backup WireGuard config
cp /etc/wireguard/wg0.conf /root/wg0.conf.backup
```

### Uninstall (Jika Dibutuhkan)

```bash
systemctl stop wgui wg-autoreload wg-quick@wg0
systemctl disable wgui wg-autoreload wg-quick@wg0
rm -rf /opt/wireguard-ui /etc/wireguard /etc/systemd/system/wgui.service
```

## 📁 Struktur File Penting

| Path | Fungsi |
|------|--------|
| `/etc/wireguard/wg0.conf` | Konfigurasi utama WireGuard |
| `/opt/wireguard-ui/db/` | Database user (plaintext JSON) |
| `/opt/wireguard-ui/wireguard-ui` | Binary WG-UI |
| `/root/wgui_credentials.txt` | Credentials admin |
| `/var/log/wg-autoreload.log` | Log auto-reload |
| `/usr/local/bin/wg-auto-reload.sh` | Script auto-reload |

## 🛡️ Keamanan

- ✅ Port 5000 **hanya bisa diakses via localhost**
- ✅ Database disimpan plaintext (fix untuk bug WG-UI)
- ✅ Firewall default mengizinkan hanya SSH, WireGuard & loopback
- ✅ Fail2ban proteksi SSH brute force
- ✅ Auto-backup private key sebelum perubahan

## ⚠️ Catatan Penting

1. **Database plaintext** sengaja digunakan untuk menghindari error parse JSON di WG-UI.
2. **Auto-reload** butuh `inotify-tools`, sudah diinstall script.
3. **Iptables rules** akan hilang jika reboot sebelum disave, script sudah menyimpan ke `/etc/iptables/rules.v4`.
4. **Ganti password admin** setelah login pertama.

## 📋 Persyaratan Sistem

- **OS:** Ubuntu 18.04+ / Debian 10+
- **RAM:** Minimal 512MB
- **Storage:** 1GB free space
- **Root access:** Required

## 🐛 Common Issues

### Client Config Tidak Bisa Connect

**Penyebab umum:**
- Firewall blocking port 51820 → `iptables -L INPUT -v -n | grep 51820`
- MTU terlalu besar → Turunkan ke `1400` di config client
- Endpoint salah → Cek `WGUI_ENDPOINT_ADDRESS` di `/etc/systemd/system/wgui.service`

### Cek Koneksi Client

```bash
sudo wg show
```

Output akan menampilkan peer, transfer data, & handshake terakhir.

## 📞 Dukungan

Jika ada masalah:
1. Cek log: `journalctl -u wgui -f`
2. Cek koneksi: `wg show`
3. Restart services: `systemctl restart wgui wg-quick@wg0`

## 📄 Lisensi

MIT License - silakan digunakan, dimodifikasi, dan didistribusikan.

---

**Dibuat dengan ❤️ untuk production WireGuard VPN servers**

[![GitHub stars](https://img.shields.io/github/stars/soranewa/wireguardyb)](https://github.com/soranewa/wireguardyb/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/soranewa/wireguardyb)](https://github.com/soranewa/wireguardyb/network)
```

