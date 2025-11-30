#!/usr/bin/env bash
set -e
echo "=== Debian Small-Disk Mode Configuration ==="
# 1. Limit systemd-journald size
echo "Configuring journald size limits..."
sudo sed -i 's/^#SystemMaxUse=.*//g' /etc/systemd/journald.conf
sudo sed -i 's/^#SystemMaxFileSize=.*//g' /etc/systemd/journald.conf
sudo sed -i 's/^#SystemMaxFiles=.*//g' /etc/systemd/journald.conf
sudo bash -c 'cat >> /etc/systemd/journald.conf <<EOF
SystemMaxUse=10M
SystemMaxFileSize=5M
SystemMaxFiles=2
EOF'
# 2. Enable volatile logs (stored in RAM only)
echo "Switching journald to volatile mode (RAM-only logging)..."
sudo sed -i 's/^#Storage=.*/Storage=volatile/' /etc/systemd/journald.conf
# Remove persistent logs if they exist
sudo rm -rf /var/log/journal || true
# 3. Disable rsyslog (optional, most machines do not need it)
if systemctl is-active --quiet rsyslog; then
    echo "Disabling rsyslog service..."
    sudo systemctl disable --now rsyslog
else
    echo "rsyslog already disabled."
fi
# 4. Configure aggressive logrotate
echo "Configuring logrotate..."
sudo sed -i 's/^weekly/daily/' /etc/logrotate.conf
sudo sed -i 's/^rotate .*/rotate 2/' /etc/logrotate.conf
sudo sed -i '/size /d' /etc/logrotate.conf
echo "size 100k" | sudo tee -a /etc/logrotate.conf
# 5. Symlink noisy logs to /dev/null
echo "Silencing noisy logs..."
NOISY_LOGS=(
    /var/log/apt/history.log
    /var/log/apt/term.log
    /var/log/wtmp
    /var/log/btmp
)
for log in "${NOISY_LOGS[@]}"; do
    sudo rm -f "$log"
    sudo ln -s /dev/null "$log"
done
# 6. Clean existing logs
echo "Vacuuming existing journal logs..."
sudo journalctl --vacuum-size=10M
echo "Restarting journald..."
sudo systemctl restart systemd-journald
echo "=== Small-Disk Mode Applied Successfully ==="
echo "Your system now uses minimal logging and minimal storage."
