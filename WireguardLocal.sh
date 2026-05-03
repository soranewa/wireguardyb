#!/bin/bash
set -e

echo "=== INSTALL WIREGUARD + WG-UI (SIMPLIFIED) ==="

# Root check
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# ==================== CONFIGURATION ====================
ENABLE_IPV6_DISABLE=false
PRESERVE_DB=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --disable-ipv6)
            ENABLE_IPV6_DISABLE=true
            shift
            ;;
        --reset-db)
            PRESERVE_DB=false
            shift
            ;;
        *)
            echo "Usage: $0 [--disable-ipv6] [--reset-db]"
            exit 1
            ;;
    esac
done

# ==================== DETECT ARCHITECTURE ====================
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)
        WGUI_ARCH="amd64"
        ;;
    aarch64|arm64)
        WGUI_ARCH="arm64"
        ;;
    armv7l|armhf)
        WGUI_ARCH="armv7"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac
echo "Detected architecture: $ARCH -> $WGUI_ARCH"

WGUI_VERSION="v0.6.2"
WGUI_URL="https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.6.2/wireguard-ui-v0.6.2-linux-${WGUI_ARCH}.tar.gz"

# ==================== UPDATE & DEPENDENCIES ====================
apt update -y
apt install -y wireguard curl wget iptables iptables-persistent inotify-tools jq openssl

# ==================== DETECT INTERFACE ====================
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
[ -z "$MAIN_IF" ] && MAIN_IF="eth0"

# ==================== GET SERVER IP ====================
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Server IP: $SERVER_IP"

# ==================== CREATE DIRECTORIES ====================
mkdir -p /opt/wireguard-ui /etc/wireguard

# ==================== DB HANDLING ====================
if [ "$PRESERVE_DB" = false ] || [ ! -d /opt/wireguard-ui/db ]; then
    rm -rf /opt/wireguard-ui/db
    mkdir -p /opt/wireguard-ui/db/users
    ADMIN_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' </dev/urandom | head -c 12)
    [ -z "$ADMIN_PASS" ] && ADMIN_PASS="admin$(date +%s | tail -c 6)"
    
    cat > /opt/wireguard-ui/db/users/admin.json <<EOF
{"username":"admin","password":"$ADMIN_PASS","admin":true}
EOF

    cat > /root/wgui_credentials.txt <<EOF
========================================
WIREGUARD UI - LOGIN INFO
URL: http://127.0.0.1:5000
Username: admin
Password: $ADMIN_PASS
Access: ssh -L 5000:127.0.0.1:5000 root@$SERVER_IP
========================================
EOF
    chmod 600 /root/wgui_credentials.txt
    echo "✓ Admin created | Pass: $ADMIN_PASS"
else
    echo "✓ Existing database preserved"
fi

# ==================== GENERATE KEYS ====================
if [ ! -f /etc/wireguard/privatekey ]; then
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
fi
PRIVATE_KEY=$(cat /etc/wireguard/privatekey)

# ==================== DOWNLOAD WG-UI (ARCH DETECT) ====================
cd /opt/wireguard-ui
echo "Downloading WireGuard-UI for $WGUI_ARCH..."
wget -q --show-progress -O wg-ui.tar.gz "$WGUI_URL"
tar -xzf wg-ui.tar.gz
chmod +x wireguard-ui
echo "✓ WireGuard-UI installed"

# ==================== SYSCTL ====================
sysctl -w net.ipv4.ip_forward=1
grep -qxF "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

[ "$ENABLE_IPV6_DISABLE" = true ] && {
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    grep -qxF "net.ipv6.conf.all.disable_ipv6=1" /etc/sysctl.conf || echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
}

# ==================== WG0.CONF (1 BARIS POSTUP/POSTDOWN) ====================
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.252.1.1/24
ListenPort = 51820
PrivateKey = $PRIVATE_KEY
MTU = 1420
PostUp = iptables -t nat -A POSTROUTING -o $MAIN_IF -j MASQUERADE; iptables -A INPUT -p udp --dport 51820 -j ACCEPT; iptables -A INPUT -i wg0 -j ACCEPT; iptables -A INPUT -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT; iptables -A INPUT -p tcp --dport 5000 -j DROP; iptables -A FORWARD -i wg0 -o $MAIN_IF -j ACCEPT; iptables -A FORWARD -i $MAIN_IF -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $MAIN_IF -j MASQUERADE; iptables -D INPUT -p udp --dport 51820 -j ACCEPT; iptables -D INPUT -i wg0 -j ACCEPT; iptables -D INPUT -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT; iptables -D INPUT -p tcp --dport 5000 -j DROP; iptables -D FORWARD -i wg0 -o $MAIN_IF -j ACCEPT; iptables -D FORWARD -i $MAIN_IF -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
EOF

# ==================== AUTO RELOAD (TETAP ADA) ====================
cat > /usr/local/bin/wg0-autoreload.sh <<'EOF'
#!/bin/bash
CONFIG="/etc/wireguard/wg0.conf"
LOG_FILE="/var/log/wg0-autoreload.log"
LAST_RUN=0

while inotifywait -e modify -e move -e delete $CONFIG 2>/dev/null; do
    NOW=$(date +%s)
    [ $((NOW - LAST_RUN)) -lt 2 ] && continue
    LAST_RUN=$NOW
    echo "[$(date)] Config changed, waiting..." >> $LOG_FILE
    sleep 2
    if ! ip link show wg0 > /dev/null 2>&1; then
        echo "[$(date)] WG not up, starting..." >> $LOG_FILE
        wg-quick up wg0 2>> $LOG_FILE
    else
        echo "[$(date)] Reloading..." >> $LOG_FILE
        if wg syncconf wg0 <(wg-quick strip wg0) 2>> $LOG_FILE; then
            echo "[$(date)] ✓ Reload success" >> $LOG_FILE
        else
            echo "[$(date)] ✗ Sync failed, restarting..." >> $LOG_FILE
            wg-quick down wg0 2>> $LOG_FILE; sleep 2; wg-quick up wg0 2>> $LOG_FILE
        fi
    fi
done
EOF
chmod +x /usr/local/bin/wg0-autoreload.sh

# ==================== SYSTEMD SERVICES ====================
cat > /etc/systemd/system/wg0-autoreload.service <<EOF
[Unit]
Description=WireGuard Auto Reload
After=network-online.target wg-quick@wg0.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/wg0-autoreload.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/wgui.service <<EOF
[Unit]
Description=WireGuard UI
After=network-online.target wg-quick@wg0.service

[Service]
WorkingDirectory=/opt/wireguard-ui
ExecStart=/opt/wireguard-ui/wireguard-ui
Environment="WGUI_DATABASE_PATH=/opt/wireguard-ui/db"
Environment="WGUI_LISTEN_ADDRESS=127.0.0.1:5000"
Environment="WGUI_MANAGE_START=true"
Environment="WGUI_MANAGE_RESTART=true"
Environment="WGUI_CONFIG_FILE_PATH=/etc/wireguard/wg0.conf"
Environment="WGUI_ENDPOINT_ADDRESS=$SERVER_IP"
Environment="WGUI_ENDPOINT_PORT=51820"
Environment="WGUI_SERVER_INTERFACE_ADDRESSES=10.252.1.1/24"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ==================== SAVE IPTABLES & START ====================
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

systemctl daemon-reload
systemctl enable wg-quick@wg0 2>/dev/null || true
systemctl enable wg0-autoreload wgui

wg-quick up wg0 2>/dev/null || true
sleep 2
systemctl start wg0-autoreload wgui

# ==================== FINAL OUTPUT ====================
echo ""
echo "========================================="
echo "✅ INSTALLATION COMPLETED"
echo "========================================="
wg show wg0 2>/dev/null && echo "✅ WireGuard: RUNNING" || echo "⚠️  WireGuard: NOT RUNNING"
systemctl is-active --quiet wg0-autoreload && echo "✅ Auto-reload: RUNNING"
systemctl is-active --quiet wgui && echo "✅ WG-UI: RUNNING"

if [ -f /root/wgui_credentials.txt ]; then
    cat /root/wgui_credentials.txt
fi
echo "========================================="
