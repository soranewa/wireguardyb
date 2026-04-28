# WireGuard + WG-UI Setup (Stable NAT Config)

## 🚀 Tujuan

Setup WireGuard VPN + WG-UI dengan:

* Internet tembus (NAT)
* Routing stabil
* Support banyak client
* Mudah digunakan via Web UI

---

## ⚙️ Konfigurasi WG-UI

Masuk ke **WG-UI → Server Settings**, isi:

### Server Interface Addresses

```
10.252.1.1/24
```

### Listen Port

```
51820
```

---

## 🔥 Post Up Script (WAJIB)

Copy **1 baris penuh** ini (jangan enter):

```
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE || iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -C FORWARD -i wg0 -o eth0 -j ACCEPT || iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT; iptables -C FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -C INPUT -i wg0 -j ACCEPT || iptables -A INPUT -i wg0 -j ACCEPT
```

---

## 🧹 Pre Down Script (WAJIB)

Copy **1 baris penuh** ini:

```
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null; iptables -D FORWARD -i wg0 -o eth0 -j ACCEPT 2>/dev/null; iptables -D FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
```

---

## ❌ Post Down Script

Kosongkan

---

## ⚠️ Penting

### Aktifkan IP Forward

```
sysctl -w net.ipv4.ip_forward=1
```

Permanent:

```
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

---

### Pastikan Interface Benar

Cek:

```
ip route
```

Contoh:

```
default via xxx dev eth0
```

Jika bukan `eth0`, ganti semua `eth0` di script sesuai interface (misal `ens3`).

---

## 🔁 Apply Config

Restart WireGuard:

```
wg-quick down wg0
wg-quick up wg0
```

Atau:

```
systemctl restart wg-quick@wg0
```

---

## 🧪 Testing

Dari client:

```
ping 8.8.8.8
```

Buka:

```
https://google.com
```

---

## 🛠️ Troubleshooting

### Connect tapi tidak ada internet

Cek:

```
sysctl net.ipv4.ip_forward
```

Harus:

```
net.ipv4.ip_forward = 1
```

---

### Internet lambat / beberapa aplikasi tidak jalan

Turunkan MTU ke:

```
1420
```

---

### Masih gagal

Cek:

```
iptables -t nat -L -n -v
wg
ip route
```

---

## 🔐 Tips Security

* Ganti port default 51820
* Gunakan subnet berbeda (contoh 10.10.0.0/24)
* Jangan expose WG-UI ke publik
* Gunakan SSH tunnel untuk akses UI

---

## 🎯 Summary

| Setting   | Value         |
| --------- | ------------- |
| Interface | 10.252.1.1/24 |
| Port      | 51820         |
| NAT       | Enabled       |
| Internet  | Working       |
| Stability | High          |

---

## 🚀 Done

WireGuard siap digunakan untuk VPN pribadi atau bisnis.
