# WireGuard + WG-UI Production Installer

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passed-brightgreen.svg)](https://www.shellcheck.net/)

Script instalasi otomatis untuk **WireGuard VPN Server** dengan **Web UI** (WireGuard-UI) yang sudah di-FIX untuk masalah database plaintext.

---

## ✨ Fitur

* Instalasi WireGuard + WireGuard-UI
* Fix database plaintext
* Auto-reload tanpa disconnect
* Firewall secure
* Fail2ban opsional

---

## 🚀 Cara Install

```bash
curl -O https://raw.githubusercontent.com/soranewa/wireguardyb/refs/heads/main/WireguardYB.sh
chmod +x WireguardYB.sh
sudo ./WireguardYB.sh
```

---

## 🔐 Akses Web UI

```bash
ssh -L 5000:127.0.0.1:5000 root@IP
```

Buka di browser:
http://localhost:5000

---

## ⚙️ Konfigurasi WireGuard (WAJIB)

### 🔹 Post-Up Script

Copy **1 baris penuh** ini ke field **Post-Up Script**:

```bash
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE || iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -C FORWARD -i wg0 -o eth0 -j ACCEPT || iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT; iptables -C FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -C INPUT -i wg0 -j ACCEPT || iptables -A INPUT -i wg0 -j ACCEPT
```

---

### 🔹 Pre-Down Script

Copy **1 baris penuh** ini ke field **Pre-Down Script**:

```bash
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null; iptables -D FORWARD -i wg0 -o eth0 -j ACCEPT 2>/dev/null; iptables -D FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
```

---

### ⚠️ Catatan Penting

* Ganti `eth0` jika interface berbeda

Cek interface:

```bash
ip route | grep default
```

Contoh:

```
eth0 → ens3 / venet0 / dll
```

---

## 📁 File Penting

* `/etc/wireguard/wg0.conf`
* `/opt/wireguard-ui/db/`
* `/root/wgui_credentials.txt`

---

## 🛡️ Security

* Port 5000 hanya localhost (via SSH tunnel)
* Firewall aktif
* Fail2ban protection

---

## ⚠️ Catatan

* Ganti password setelah login
* MTU default: 1420 (turunkan ke 1400 jika bermasalah)

---

## 📄 License

MIT
