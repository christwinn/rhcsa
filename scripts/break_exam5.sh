#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 5 BREAK SCRIPT
# Title: Full Comprehensive Simulation
# Difficulty: 5/5
# Time Limit: 210 minutes
# Tasks: 20
# ============================================================
# Run as root. Snapshot before running.
# ============================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash break_exam5.sh). Snapshot your VM first."
  exit 1
fi
LOG="/var/log/rhcsa_mock_exam5.log"
echo "[$(date)] Mock Exam 5: Full Simulation - Break started" | tee "$LOG"

# Lock root
passwd -l root || true
chage -M 1 -m 1 -W 0 root 2>/dev/null || true

echo "[BREAK] Root locked" | tee -a "$LOG"

# Users/groups
if id examuser1 &>/dev/null; then userdel -r examuser1 2>/dev/null || true; fi
if id examuser2 &>/dev/null; then userdel -r examuser2 2>/dev/null || true; fi
getent group examusers && groupdel examusers 2>/dev/null || true
rm -f /etc/sudoers.d/examuser1

echo "[BREAK] Users and sudo removed" | tee -a "$LOG"

# Directories
rm -rf /data/exam /secure/exam /web

echo "[BREAK] Shared directories removed" | tee -a "$LOG"

# Storage
if [ -b /dev/sdb ]; then
  DEVICE=sdb
  PART=sdb1
else if [ -b /dev/vdb ]; then
  DEVICE=vdb
  PART=vdb1
fi fi

if [ ! -z DEVICE ]; then
    wipefs -a /dev/$DEVICE 2>/dev/null || true
    vgremove -y vg_final 2>/dev/null || true
    pvremove -y /dev/$PART 2>/dev/null || true
    parted -s /dev/$DEVICE mklabel msdos 2>/dev/null || true
fi
umount -f /mnt/final /mnt/nfsexam /mnt/labeled 2>/dev/null || true
sed -i '/\/mnt\/final/d; /\/mnt\/nfsexam/d; /\/mnt\/labeled/d' /etc/fstab 2>/dev/null || true
rm -rf /mnt/final /mnt/nfsexam /mnt/labeled

echo "[BREAK] LVM and storage mounts removed" | tee -a "$LOG"

# Remove swap LV
if [ -b /dev/vg_final/lv_swap ]; then
    swapoff /dev/vg_final/lv_swap 2>/dev/null || true
    lvremove -y vg_final/lv_swap 2>/dev/null || true
fi

echo "[BREAK] swap removed" | tee -a "$LOG"

# SELinux
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
setsebool -P httpd_can_network_connect 0 2>/dev/null || true
semanage port -d -t http_port_t -p tcp 8443 2>/dev/null || true

echo "[BREAK] SELinux reset" | tee -a "$LOG"

# Firewalld
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
firewall-cmd --remove-port=80/tcp --permanent 2>/dev/null || true
firewall-cmd --remove-port=443/tcp --permanent 2>/dev/null || true
firewall-cmd --remove-port=8443/tcp --permanent 2>/dev/null || true
firewall-cmd --remove-service=http --permanent 2>/dev/null || true
firewall-cmd --remove-service=https --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "[BREAK] firewalld disabled" | tee -a "$LOG"

# Apache/container
systemctl disable httpd 2>/dev/null || true
systemctl stop httpd 2>/dev/null || true
systemctl disable container-examweb 2>/dev/null || true
systemctl stop container-examweb 2>/dev/null || true
podman rm -f examweb 2>/dev/null || true
podman rmi -a 2>/dev/null || true
rm -f /etc/systemd/system/container-examweb.service

echo "[BREAK] httpd and container removed" | tee -a "$LOG"

# Network
IFACE=$(nmcli -t -f DEVICE,TYPE device show | grep ethernet | head -n2 | tail -n1 | cut -d: -f1)
if [[ -n "$IFACE" ]]; then
    nmcli connection down "$IFACE" 2>/dev/null || true
    nmcli connection delete "$IFACE" 2>/dev/null || true
fi
hostnamectl set-hostname broken5.example.com 2>/dev/null || true
sed -i '/192.168.30.30/d' /etc/hosts 2>/dev/null || true

echo "[BREAK] network reset" | tee -a "$LOG"

# SSH config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
systemctl restart sshd 2>/dev/null || true

echo "[BREAK] SSH config reversed" | tee -a "$LOG"

# systemd target and services
systemctl set-default graphical.target 2>/dev/null || true
systemctl disable sshd 2>/dev/null || true
systemctl stop sshd 2>/dev/null || true
systemctl disable chronyd 2>/dev/null || true
systemctl stop chronyd 2>/dev/null || true
systemctl disable crond 2>/dev/null || true
systemctl stop crond 2>/dev/null || true

echo "[BREAK] target and services reset" | tee -a "$LOG"

# chrony
sed -i 's/^pool.*/# pool removed/' /etc/chrony.conf 2>/dev/null || true

# rsyslog
rm -f /etc/rsyslog.d/exam_secure.conf
systemctl restart rsyslog 2>/dev/null || true

# sysctl
rm -f /etc/sysctl.d/99-kernel.conf

# journald
rm -rf /var/log/journal

# scripts and timers
rm -f /usr/local/bin/exam_backup.sh /usr/local/bin/exam_alert.sh /usr/local/bin/disk_usage.sh
rm -f /etc/systemd/system/exam.timer /etc/systemd/system/exam.service
systemctl daemon-reload 2>/dev/null || true
atq 2>/dev/null | awk '{print $1}' | xargs -r atrm 2>/dev/null || true

echo "[BREAK] scripts/timers/cron/at removed" | tee -a "$LOG"

# cron
 crontab -l 2>/dev/null | grep -v exam_backup | crontab - 2>/dev/null || true

# repos/packages
rm -f /etc/yum.repos.d/exam5.repo

echo "[BREAK] repo removed" | tee -a "$LOG"

# tuned
systemctl stop tuned 2>/dev/null || true
systemctl disable tuned 2>/dev/null || true

# logrotate
rm -f /etc/logrotate.d/exam5

# autofs
systemctl disable autofs 2>/dev/null || true
systemctl stop autofs 2>/dev/null || true
rm -f /etc/auto.remote
sed -i '/\/remote\/exam/d' /etc/auto.master 2>/dev/null || true

echo "[BREAK] autofs removed" | tee -a "$LOG"

echo "[$(date)] Mock Exam 5: Break complete." | tee -a "$LOG"
