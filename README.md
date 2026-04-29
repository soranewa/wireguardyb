# WireGuard + Wireguard UI Installer

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passed-brightgreen.svg)](https://www.shellcheck.net/)

Script instalasi otomatis untuk **WireGuard VPN Server** dengan **Web UI** (WireGuard-UI).

---

## ✨ Fitur

* Instalasi WireGuard + WireGuard-UI
* Auto Reload Tanpa Disconnect
* Firewall Secure Opsional
* Fail2ban Opsional

---

## 🚀 Cara Install

```bash id="i8v2qx"
curl -O https://raw.githubusercontent.com/soranewa/wireguardyb/refs/heads/main/WireguardYB.sh
chmod +x WireguardYB.sh
sudo ./WireguardYB.sh
```

---

## 🔐 Akses Web UI

```bash id="w2k19x"
ssh -L 5000:127.0.0.1:5000 root@IP-Server-Anda
```

Buka di browser:
http://localhost:5000

---

## ⚙️ Konfigurasi WireGuard (Wajib)

### 🔹 Post-Up Script

Copy **1 baris penuh** ini ke field **Post-Up Script**:

```bash id="k9d3ls"
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE || iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -C FORWARD -i wg0 -o eth0 -j ACCEPT || iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT; iptables -C FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -C INPUT -i wg0 -j ACCEPT || iptables -A INPUT -i wg0 -j ACCEPT
```

---

### 🔹 Pre-Down Script

Copy **1 baris penuh** ini ke field **Pre-Down Script**:

```bash id="v7m1pz"
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null; iptables -D FORWARD -i wg0 -o eth0 -j ACCEPT 2>/dev/null; iptables -D FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
```

---

### ⚠️ Catatan Penting

* Ganti `eth0` jika interface berbeda

Cek interface:

```bash id="m3o0kd"
ip route | grep default
```

Contoh:

```
eth0 → ens3 / venet0 / dll
```

---

## ⚙️ Parameter & Opsi Script (Advanced)

Script ini memiliki beberapa **flag (parameter khusus)**:

---

### 🔹 `--disable-ipv6`

```bash id="y2n8qf"
./WireguardYB.sh --disable-ipv6
```

**Fungsi:**

* Disable IPv6
* Mencegah DNS leak

---

### 🔹 `--strict-firewall`

```bash id="d0s9we"
./WireguardYB.sh --strict-firewall
```

**Fungsi:**

* Firewall mode DROP (super ketat)
* Hanya izinkan SSH, WG, dan localhost UI

**Peringatan:**

* Port lain akan ke-block

---

### 🔹 `--no-fail2ban`

```bash id="p9x3zk"
./WireguardYB.sh --no-fail2ban
```

**Fungsi:**

* Skip install fail2ban

---

### 🔹 `--reset-db`

```bash id="q1l8rt"
./WireguardYB.sh --reset-db
```

**Fungsi:**

* Hapus database lama
* Reset semua user
* Generate password baru

⚠️ Semua client akan hilang

---

## 🔗 Kombinasi Parameter

```bash id="f8v2aa"
./WireguardYB.sh --disable-ipv6 --strict-firewall
```

---

## 🤖 Fitur Otomatis (Background)

### 🔸 Auto Port Detection

* Deteksi port SSH otomatis
* Hindari lockout

### 🔸 Auto Reload WireGuard

* Pakai `inotify-tools`
* Auto sync tanpa disconnect

### 🔸 Credential Logger

Disimpan di:

```id="r2w7ka"
/root/wgui_credentials.txt
```

---

## 📁 File Penting

* `/etc/wireguard/wg0.conf`
* `/opt/wireguard-ui/db/`
* `/root/wgui_credentials.txt`

---

## 🛡️ Security

* Port 5000 hanya localhost
* Firewall aktif
* Fail2ban protection

---

## ⚠️ Catatan

* Ganti password setelah login
* MTU default: 1480 (turunkan ke 1280 jika perlu)

---

## 📄 License

MIT
