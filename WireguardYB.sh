#!/bin/bash
set -e

echo "=== INSTALL WIREGUARD + WG-UI (PLAINTEXT FIX) ==="

# Root check
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# ==================== CONFIGURATION ====================
WGUI_VERSION="v0.6.2"
WGUI_URL="https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.6.2/wireguard-ui-v0.6.2-linux-amd64.tar.gz"
ENABLE_IPV6_DISABLE=false
ENABLE_STRICT_FIREWALL=false
ENABLE_FAIL2BAN=true
PRESERVE_DB=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --disable-ipv6)
            ENABLE_IPV6_DISABLE=true
            shift
            ;;
        --strict-firewall)
            ENABLE_STRICT_FIREWALL=true
            shift
            ;;
        --no-fail2ban)
            ENABLE_FAIL2BAN=false
            shift
            ;;
        --reset-db)
            PRESERVE_DB=false
            shift
            ;;
        *)
            echo "Usage: $0 [--disable-ipv6] [--strict-firewall] [--no-fail2ban] [--reset-db]"
            exit 1
            ;;
    esac
done

# ==================== UPDATE & DEPENDENCIES ====================
apt update -y
apt install -y wireguard curl wget iptables iptables-persistent inotify-tools jq logrotate openssl

# ==================== DETECT INTERFACE & MTU ====================
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$MAIN_IF" ]; then
    MAIN_IF="eth0"
fi

MTU=1420
echo "Using MTU: $MTU"

# ==================== DETECT SSH PORT ====================
SSH_PORT=$(ss -tulnp 2>/dev/null | grep -E 'sshd|dropbear' | grep -oP '(?<=:)\d+(?= )' | head -1)
if [ -z "$SSH_PORT" ]; then
    SSH_PORT=22
fi
echo "Detected SSH port: $SSH_PORT"

# ==================== GET SERVER IP (ROBUST) ====================
SERVER_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -4 -s --max-time 5 icanhazip.com 2>/dev/null)
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
fi
echo "Server IP: $SERVER_IP"

# ==================== CREATE DIRECTORIES ====================
mkdir -p /opt/wireguard-ui
mkdir -p /etc/wireguard
mkdir -p /etc/fail2ban

# ==================== DB HANDLING (PLAINTEXT - FIX WG-UI BUG) ====================
if [ "$PRESERVE_DB" = false ] || [ ! -d /opt/wireguard-ui/db ]; then
    rm -rf /opt/wireguard-ui/db
    mkdir -p /opt/wireguard-ui/db/users
    echo "✓ Fresh database created"

    # Generate random password (12 characters)
    ADMIN_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' </dev/urandom | head -c 12)
    
    # Fallback if tr fails (just in case)
    if [ -z "$ADMIN_PASS" ]; then
        ADMIN_PASS="admin$(date +%s | tail -c 6)"
    fi

    cat > /opt/wireguard-ui/db/users/admin.json <<EOF
{
  "username": "admin",
  "password": "$ADMIN_PASS",
  "admin": true
}
EOF

    echo "✓ Admin user created"
    echo "🔐 Username: admin"
    echo "🔑 Password: $ADMIN_PASS"

    # Save credentials to file
    cat > /root/wgui_credentials.txt <<EOF
========================================
WIREGUARD UI - LOGIN INFO
========================================
URL         : http://127.0.0.1:5000
Username    : admin
Password    : $ADMIN_PASS

⚠️  SAVE THIS PASSWORD! It will not be shown again.

ACCESS: ssh -L 5000:127.0.0.1:5000 root@$SERVER_IP
Then open http://localhost:5000

To change password:
  1. Login with above credentials
  2. Go to Settings → Profile
  3. Change to your own password
========================================
EOF

    chmod 600 /root/wgui_credentials.txt

else
    echo "✓ Existing database preserved (admin password unchanged)"
    # Show existing credentials if file exists
    if [ -f /root/wgui_credentials.txt ]; then
        echo "📁 Existing credentials: cat /root/wgui_credentials.txt"
    fi
fi

# ==================== CLEAN OLD BINARY ====================
rm -rf /opt/wireguard-ui/wireguard-ui
rm -f /opt/wireguard-ui/wg-ui.tar.gz

# ==================== BACKUP & GENERATE KEYS ====================
if [ -f /etc/wireguard/privatekey ]; then
    BACKUP_TIME=$(date +%s)
    cp /etc/wireguard/privatekey /etc/wireguard/privatekey.bak.$BACKUP_TIME
    echo "✓ Backup private key created"
else
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
fi

PRIVATE_KEY=$(cat /etc/wireguard/privatekey)

# ==================== DOWNLOAD WG-UI ====================
cd /opt/wireguard-ui
echo "Downloading WireGuard-UI $WGUI_VERSION..."
if ! wget -q --show-progress -O wg-ui.tar.gz "$WGUI_URL"; then
    echo "ERROR: Failed to download WG-UI"
    exit 1
fi

tar -xzf wg-ui.tar.gz
if [ ! -f wireguard-ui ]; then
    echo "ERROR: Failed to extract"
    exit 1
fi
chmod +x wireguard-ui
echo "✓ WireGuard-UI installed"

# ==================== SYSCTL ====================
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

if [ "$ENABLE_IPV6_DISABLE" = true ]; then
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
fi

# ==================== IPTABLES (CLEAN START) ====================
iptables-save > /etc/iptables/rules.v4.bak.$(date +%s) 2>/dev/null || true

# Clear only WG-related chains (safe)
iptables -t nat -D POSTROUTING -o $MAIN_IF -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i wg0 -o $MAIN_IF -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i $MAIN_IF -o wg0 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p udp --dport 51820 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p tcp --dport 5000 -j DROP 2>/dev/null || true
iptables -D INPUT -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT 2>/dev/null || true

# ==================== CREATE WG0.CONF (TANPA DNS) ====================
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.252.1.1/24
ListenPort = 51820
PrivateKey = $PRIVATE_KEY
MTU = $MTU

# NAT Masquerade
PostUp = iptables -t nat -C POSTROUTING -o $MAIN_IF -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o $MAIN_IF -j MASQUERADE

# Open WireGuard port
PostUp = iptables -C INPUT -p udp --dport 51820 -j ACCEPT 2>/dev/null || iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# Allow WG subnet to server
PostUp = iptables -C INPUT -i wg0 -j ACCEPT 2>/dev/null || iptables -A INPUT -i wg0 -j ACCEPT

# Block port 5000 from public (only localhost)
PostUp = iptables -C INPUT -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT
PostUp = iptables -C INPUT -p tcp --dport 5000 -j DROP 2>/dev/null || iptables -A INPUT -p tcp --dport 5000 -j DROP

# FORWARD: dari WG ke Internet
PostUp = iptables -C FORWARD -i wg0 -o $MAIN_IF -j ACCEPT 2>/dev/null || iptables -A FORWARD -i wg0 -o $MAIN_IF -j ACCEPT

# FORWARD: dari Internet ke WG
PostUp = iptables -C FORWARD -i $MAIN_IF -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A FORWARD -i $MAIN_IF -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Cleanup
PostDown = iptables -t nat -D POSTROUTING -o $MAIN_IF -j MASQUERADE 2>/dev/null
PostDown = iptables -D INPUT -p udp --dport 51820 -j ACCEPT 2>/dev/null
PostDown = iptables -D INPUT -i wg0 -j ACCEPT 2>/dev/null
PostDown = iptables -D INPUT -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT 2>/dev/null
PostDown = iptables -D INPUT -p tcp --dport 5000 -j DROP 2>/dev/null
PostDown = iptables -D FORWARD -i wg0 -o $MAIN_IF -j ACCEPT 2>/dev/null
PostDown = iptables -D FORWARD -i $MAIN_IF -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
EOF

# ==================== STRICT FIREWALL ====================
if [ "$ENABLE_STRICT_FIREWALL" = true ]; then
    echo ""
    echo "⚠️  APPLYING STRICT FIREWALL"
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        iptables -F INPUT
        iptables -F FORWARD
        
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A INPUT -p udp --dport 51820 -j ACCEPT
        iptables -A INPUT -i wg0 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5000 -j DROP
        
        iptables -A FORWARD -i wg0 -o $MAIN_IF -j ACCEPT
        iptables -A FORWARD -i $MAIN_IF -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        
        echo "✓ Strict firewall applied"
    fi
fi

# ==================== SAVE IPTABLES ====================
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

# ==================== AUTO RELOAD ====================
cat > /usr/local/bin/wg-auto-reload.sh <<'EOF'
#!/bin/bash
CONFIG="/etc/wireguard/wg0.conf"
LOG_FILE="/var/log/wg-autoreload.log"
LAST_RUN=0

while inotifywait -e modify -e move -e delete $CONFIG 2>/dev/null; do
    NOW=$(date +%s)
    if [ $((NOW - LAST_RUN)) -lt 2 ]; then
        continue
    fi
    LAST_RUN=$NOW
    
    echo "[$(date)] Config changed, waiting..." >> $LOG_FILE
    sleep 2
    
    if ! ip link show wg0 > /dev/null 2>&1; then
        echo "[$(date)] WG not up, starting..." >> $LOG_FILE
        wg-quick up wg0 2>> $LOG_FILE
    else
        echo "[$(date)] Reloading (no disconnect)..." >> $LOG_FILE
        if wg syncconf wg0 <(wg-quick strip wg0) 2>> $LOG_FILE; then
            echo "[$(date)] ✓ Reload successful" >> $LOG_FILE
        else
            echo "[$(date)] ✗ Sync failed, restarting..." >> $LOG_FILE
            wg-quick down wg0 2>> $LOG_FILE
            sleep 2
            wg-quick up wg0 2>> $LOG_FILE
        fi
    fi
done
EOF

chmod +x /usr/local/bin/wg-auto-reload.sh

# ==================== LOGROTATE ====================
cat > /etc/logrotate.d/wireguard-ui <<EOF
/var/log/wg-autoreload.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# ==================== FAIL2BAN ====================
if [ "$ENABLE_FAIL2BAN" = true ]; then
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
backend = auto
EOF

    systemctl restart fail2ban
    echo "✓ fail2ban configured"
fi

# ==================== SYSTEMD SERVICES ====================
cat > /etc/systemd/system/wg-autoreload.service <<EOF
[Unit]
Description=WireGuard Auto Reload
After=network-online.target wg-quick@wg0.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/wg-auto-reload.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/wgui.service <<EOF
[Unit]
Description=WireGuard UI
After=network-online.target wg-quick@wg0.service
Wants=network-online.target

[Service]
WorkingDirectory=/opt/wireguard-ui
ExecStartPre=/bin/sleep 2
ExecStart=/opt/wireguard-ui/wireguard-ui
Environment=WGUI_DATABASE_PATH=/opt/wireguard-ui/db
Environment=WGUI_LISTEN_ADDRESS=127.0.0.1:5000
Environment=WGUI_MANAGE_START=true
Environment=WGUI_MANAGE_RESTART=true
Environment=WGUI_CONFIG_FILE_PATH=/etc/wireguard/wg0.conf
Environment=WGUI_ENDPOINT_ADDRESS=$SERVER_IP
Environment=WGUI_ENDPOINT_PORT=51820
Environment=WGUI_SERVER_INTERFACE_ADDRESSES=10.252.1.1/24
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ==================== ENABLE & START ====================
systemctl daemon-reload
systemctl enable wg-quick@wg0 2>/dev/null || true
systemctl enable wg-autoreload
systemctl enable wgui
systemctl enable fail2ban 2>/dev/null || true

systemctl restart wg-quick@wg0 2>/dev/null || wg-quick up wg0 2>/dev/null || true

sleep 2
if ip link show wg0 > /dev/null 2>&1; then
    echo "✓ WireGuard interface up"
else
    echo "⚠️  WireGuard interface failed to start"
fi

systemctl start wg-autoreload
systemctl start wgui

# ==================== FINAL OUTPUT ====================
echo ""
echo "========================================="
echo "✅ PRODUCTION INSTALL COMPLETED"
echo "========================================="

if wg show wg0 > /dev/null 2>&1; then
    echo "✅ WireGuard: RUNNING"
else
    echo "⚠️  WireGuard: NOT RUNNING"
fi

for svc in wg-autoreload wgui fail2ban; do
    if systemctl is-active --quiet $svc 2>/dev/null; then
        echo "✅ $svc: RUNNING"
    fi
done

echo ""
echo "🔐 LOGIN CREDENTIALS:"
if [ -f /root/wgui_credentials.txt ]; then
    cat /root/wgui_credentials.txt
else
    echo "   Username: admin"
    echo "   Password: (see above during install)"
fi
echo ""
echo "📁 Credentials saved: /root/wgui_credentials.txt"
echo "========================================="
