#!/bin/bash
# see https://learnrhcsa.com for the original 
# ============================================================
# RHCSA EX200 - MOCK EXAM 1 BREAK SCRIPT
# Title: All Core Objectives
# Difficulty: 2/5
# Time Limit: 120 minutes
# Tasks: 14
# ============================================================
# Run as root. Snapshot before running.
# ============================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash break_exam1.sh). Snapshot your VM first."
  exit 1
fi
LOG="/var/log/rhcsa_mock_exam1.log"
echo "[$(date)] Mock Exam 1: All Core Objectives - Break started" | tee "$LOG"

# Lock root
passwd -l root || true
chage -M 1 -m 1 -W 0 root 2>/dev/null || true
rm -f /.autorelabel

echo "[BREAK] Root locked, autorelabel removed" | tee -a "$LOG"

# Users/groups
if id candidate1 &>/dev/null; then userdel -r candidate1 2>/dev/null || true; fi
if id candidate2 &>/dev/null; then userdel -r candidate2 2>/dev/null || true; fi
getent group rhcsaadmins && groupdel rhcsaadmins 2>/dev/null || true
getent group rhcsausers && groupdel rhcsausers 2>/dev/null || true

echo "[BREAK] Users and groups removed" | tee -a "$LOG"

# Shared dirs
rm -rf /shared /private /web

echo "[BREAK] Shared directories removed" | tee -a "$LOG"

# Storage
if [ -b /dev/sdb ]; then
    wipefs -a /dev/sdb 2>/dev/null || true
    vgremove -y vg_exam1 2>/dev/null || true
    pvremove -y /dev/sdb1 2>/dev/null || true
    parted -s /dev/sdb mklabel msdos 2>/dev/null || true
fi
umount -f /mnt/data /mnt/nfs 2>/dev/null || true
sed -i '/\/mnt\/data/d; /\/mnt\/nfs/d' /etc/fstab 2>/dev/null || true
rm -rf /mnt/data

# remove any swap from vg_exam1
if [ -b /dev/vg_exam1/lv_swap ]; then
    swapoff /dev/vg_exam1/lv_swap 2>/dev/null || true
    lvremove -y vg_exam1/lv_swap 2>/dev/null || true
fi
if [ -b /dev/sdb2 ]; then
    swapoff /dev/sdb2 2>/dev/null || true
fi

echo "[BREAK] LVM and storage removed" | tee -a "$LOG"

# SELinux
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
setsebool -P httpd_can_network_connect 0 2>/dev/null || true
semanage port -d -t http_port_t -p tcp 8080 2>/dev/null || true

echo "[BREAK] SELinux reset" | tee -a "$LOG"

# Firewalld
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
firewall-cmd --remove-service=http --permanent 2>/dev/null || true
firewall-cmd --remove-service=https --permanent 2>/dev/null || true
firewall-cmd --remove-service=ssh --permanent 2>/dev/null || true
firewall-cmd --remove-port=8080/tcp --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "[BREAK] firewalld disabled" | tee -a "$LOG"

# systemd target and services
systemctl set-default graphical.target 2>/dev/null || true
for svc in httpd sshd chronyd; do
    systemctl disable "$svc" 2>/dev/null || true
    systemctl stop "$svc" 2>/dev/null || true
done

echo "[BREAK] target and services reset" | tee -a "$LOG"

# repos/packages
rm -f /etc/yum.repos.d/exam1.repo

echo "[BREAK] repo removed" | tee -a "$LOG"

# tuned
systemctl stop tuned 2>/dev/null || true
systemctl disable tuned 2>/dev/null || true

# sysctl
rm -f /etc/sysctl.d/99-swappiness.conf

# cron/at
rm -f /usr/local/bin/backup_etc.sh /usr/local/bin/notify.sh
rm -rf /backup
atq 2>/dev/null | awk '{print $1}' | xargs -r atrm 2>/dev/null || true
 crontab -l 2>/dev/null | grep -v backup_etc | crontab - 2>/dev/null || true

echo "[BREAK] cron/at/scripts removed" | tee -a "$LOG"

# umask
sed -i 's/^UMASK.*/UMASK 022/' /etc/login.defs 2>/dev/null || true

# Network
#IFACE=$(nmcli -t -f DEVICE,TYPE device show | grep ethernet | head -n1 | cut -d: -f1)
IFACE=$(nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE device show | grep ethernet | head -n1 | cut -d: -f1)
if [[ -n "$IFACE" ]]; then
    nmcli connection down "$IFACE" 2>/dev/null || true
    nmcli connection delete "$IFACE" 2>/dev/null || true
fi
hostnamectl set-hostname broken1.example.com 2>/dev/null || true
sed -i '/192.168.10.10/d' /etc/hosts 2>/dev/null || true

echo "[BREAK] network reset" | tee -a "$LOG"

# autofs
systemctl disable autofs 2>/dev/null || true
systemctl stop autofs 2>/dev/null || true
rm -f /etc/auto.remote
sed -i '/\/remote\/data/d' /etc/auto.master 2>/dev/null || true

echo "[BREAK] autofs removed" | tee -a "$LOG"

echo "[$(date)] Mock Exam 1: Break complete." | tee -a "$LOG"
