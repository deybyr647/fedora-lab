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
