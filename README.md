# WireGuard + WG-UI Production Installer

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passed-brightgreen.svg)](https://www.shellcheck.net/)

Script instalasi otomatis untuk **WireGuard VPN Server** dengan **Web UI** (WireGuard-UI) yang sudah di-FIX untuk masalah database plaintext.

## ✨ Fitur

* Instalasi WireGuard + WireGuard-UI
* Fix database plaintext
* Auto-reload tanpa disconnect
* Firewall secure
* Fail2ban opsional

## 🚀 Cara Install

```bash
curl -O https://raw.githubusercontent.com/soranewa/wireguardyb/refs/heads/main/WireguardYB.sh
chmod +x WireguardYB.sh
sudo ./WireguardYB.sh
```

## 🔐 Akses Web UI

```bash
ssh -L 5000:127.0.0.1:5000 root@IP
```

Buka:
http://localhost:5000

## ⚙️ Post-Up Script

```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

## 📁 File Penting

* `/etc/wireguard/wg0.conf`
* `/opt/wireguard-ui/db/`
* `/root/wgui_credentials.txt`

## 🛡️ Security

* Port 5000 localhost only
* Firewall aktif
* Fail2ban

## ⚠️ Catatan

* Ganti password setelah login
* MTU default 1420

## 📄 License

MIT
