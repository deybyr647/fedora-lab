#!/usr/bin/env bash
#
# Master Deployment Script for BorgBackup Systemd Integration
# Automates dependency installation, file generation, systemd setup, and verification.
#

set -euo pipefail

BACKUP_MOUNT="/mnt/backups"
LAB_DIR="${BACKUP_MOUNT}/lab"
REPO_PATH="${LAB_DIR}/deyby-fedora-lab"
SCRIPT_PATH="/usr/local/bin/init-backup.sh"
SERVICE_PATH="/etc/systemd/system/borg-backup.service"
TIMER_PATH="/etc/systemd/system/borg-backup.timer"

# 1. Ensure Root Privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This master script must be run as root." >&2
   exit 1
fi

echo "=== Starting BorgBackup Master Deployment ==="

# 2. Check and Install BorgBackup Package
if ! command -v borg &> /dev/null; then
    echo "[+] Installing BorgBackup via DNF..."
    dnf install -y borgbackup
else
    echo "[+] BorgBackup is already installed."
fi

# 3. Check Mount Point & Create System Directories
if [ ! -d "$BACKUP_MOUNT" ]; then
    echo "Error: Target mount directory ${BACKUP_MOUNT} is not mounted or missing." >&2
    exit 1
fi

echo "[+] Ensuring target storage, cache, and config directories exist..."
mkdir -p "$LAB_DIR" /root/.cache/borg /root/.config/borg

# 4. Initialize Borg Repository if Missing
if [ ! -d "$REPO_PATH" ]; then
    echo "[+] Initializing unencrypted Borg repository at ${REPO_PATH}..."
    borg init --encryption=none "$REPO_PATH"
else
    echo "[+] Borg repository already exists at ${REPO_PATH}."
fi

# 5. Write Execution Script (/usr/local/bin/init-backup.sh)
echo "[+] Creating ${SCRIPT_PATH}..."
cat <<'EOF' > "$SCRIPT_PATH"
#!/bin/bash
set -euo pipefail

REPO_PATH="/mnt/backups/lab/deyby-fedora-lab"

# Exclude dynamic virtual filesystems and the backup mount point itself
borg create --stats --progress "/mnt/backups/lab/deyby-fedora-lab::{now}" / \
    --exclude '/proc/*' \
    --exclude '/sys/*' \
    --exclude '/dev/*' \
    --exclude '/run/*' \
    --exclude '/mnt/*' \
    --exclude '/media/*' \
    --exclude '/tmp/*' \
    --exclude '/var/tmp/*' \
    --exclude '/var/cache/*' \
    --exclude '/lost+found'

# Prune old archives (Keep 7 daily, 4 weekly, 6 monthly)
borg prune --list --keep-daily=7 --keep-weekly=4 --keep-monthly=6 "$REPO_PATH"

# Export installed RPM package list
rpm -qa > /mnt/backups/lab/installed-packages.txt

# Export partition layout and block device structure
sfdisk -d /dev/nvme0n1 > /mnt/backups/lab/nvme-partition-layout.txt
lsblk -f > /mnt/backups/lab/lsblk-structure.txt


EOF

chmod 755 "$SCRIPT_PATH"

# 6. Write Systemd Service File (/etc/systemd/system/borg-backup.service)
echo "[+] Creating ${SERVICE_PATH}..."
cat <<'EOF' > "$SERVICE_PATH"
[Unit]
Description=BorgBackup System Full Backup
After=network.target local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/init-backup.sh
User=root
Group=root

# Enable isolated temporary space for self-tests
PrivateTmp=true

# Security hardening options
ProtectSystem=full
ReadOnlyPaths=/
ReadWritePaths=/mnt/backups /var/log /tmp /var/tmp /root/.cache/borg /root/.config/borg
EOF

chmod 644 "$SERVICE_PATH"

# 7. Write Systemd Timer File (/etc/systemd/system/borg-backup.timer)
echo "[+] Creating ${TIMER_PATH}..."
cat <<'EOF' > "$TIMER_PATH"
[Unit]
Description=Run BorgBackup daily at 3:00 AM

[Timer]
# Runs daily at 3:00 AM local time
OnCalendar=*-*-* 03:00:00

# If the system was off at 3:00 AM, run the backup immediately upon boot
Persistent=true

[Install]
WantedBy=timers.target
EOF

chmod 644 "$TIMER_PATH"

# 8. Reload Systemd and Enable Timer
echo "[+] Reloading systemd manager and enabling daily timer..."
systemctl daemon-reload
systemctl enable --now borg-backup.timer

# 9. Trigger Immediate Test Backup Run
echo "[+] Triggering immediate test backup via systemd..."
systemctl start borg-backup.service

echo "=== Deployment Complete & Initial Backup Triggered! ==="
