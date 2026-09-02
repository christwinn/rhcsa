#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 3 BREAK SCRIPT
# Title: Storage, Networking, and Scripting
# Difficulty: 3/5
# Time Limit: 150 minutes
# Tasks: 16
# ============================================================
# Run as root. Snapshot before running.
# ============================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash break_exam3.sh). Snapshot your VM first."
  exit 1
fi
LOG="/var/log/rhcsa_mock_exam3.log"
echo "[$(date)] Mock Exam 3: Storage, Networking, Scripting - Break started" | tee "$LOG"

# Lock root
passwd -l root || true
chage -M 1 -m 1 -W 0 root 2>/dev/null || true
rm -f /.autorelabel

echo "[BREAK] Root locked" | tee -a "$LOG"

# Users/groups
for u in user1 user2; do id "$u" &>/dev/null && userdel -r "$u" 2>/dev/null || true; done
for g in staff students; do getent group "$g" && groupdel "$g" 2>/dev/null || true; done

echo "[BREAK] Users/groups removed" | tee -a "$LOG"

# Directories
rm -rf /project /restricted /webdocs /tmp/exam3

echo "[BREAK] Directories removed" | tee -a "$LOG"

# Storage
if [ -b /dev/sdb ]; then
    wipefs -a /dev/sdb 2>/dev/null || true
    vgremove -y vg_exam3 2>/dev/null || true
    pvremove -y /dev/sdb1 2>/dev/null || true
    parted -s /dev/sdb mklabel msdos 2>/dev/null || true
fi
umount -f /mnt/docs /mnt/nfsexam3 2>/dev/null || true
sed -i '/\/mnt\/docs/d; /\/mnt\/nfsexam3/d' /etc/fstab 2>/dev/null || true
rm -rf /mnt/docs
if [ -b /dev/vg_exam3/lv_swap ]; then
    swapoff /dev/vg_exam3/lv_swap 2>/dev/null || true
    lvremove -y vg_exam3/lv_swap 2>/dev/null || true
fi

echo "[BREAK] Storage removed" | tee -a "$LOG"

# SELinux
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
setsebool -P httpd_can_sendmail 0 2>/dev/null || true
setsebool -P httpd_use_nfs 0 2>/dev/null || true
semanage port -d -t http_port_t -p tcp 8888 2>/dev/null || true

echo "[BREAK] SELinux reset" | tee -a "$LOG"

# Firewalld
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
for x in http https ssh nfs; do firewall-cmd --remove-service="$x" --permanent 2>/dev/null || true; done
firewall-cmd --remove-port=8888/tcp --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "[BREAK] firewalld disabled" | tee -a "$LOG"

# systemd/services
systemctl set-default graphical.target 2>/dev/null || true
for svc in httpd sshd chronyd crond; do
    systemctl disable "$svc" 2>/dev/null || true
    systemctl stop "$svc" 2>/dev/null || true
done

echo "[BREAK] systemd/services reset" | tee -a "$LOG"

# scripts, cron, at
rm -f /usr/local/bin/cleanup_tmp.sh /usr/local/bin/send_report.sh /usr/local/bin/list_large_files.sh
atq 2>/dev/null | awk '{print $1}' | xargs -r atrm 2>/dev/null || true
 crontab -l 2>/dev/null | grep -v cleanup_tmp | crontab - 2>/dev/null || true

echo "[BREAK] scripts/cron/at removed" | tee -a "$LOG"

# Network
IFACE=$(nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE device show | grep ethernet | head -n1 | cut -d: -f1)
if [[ -n "$IFACE" ]]; then
    nmcli connection down "$IFACE" 2>/dev/null || true
    nmcli connection delete "$IFACE" 2>/dev/null || true
fi
hostnamectl set-hostname broken3.example.com 2>/dev/null || true
sed -i '/192.168.30.30/d' /etc/hosts 2>/dev/null || true

echo "[BREAK] network reset" | tee -a "$LOG"

# umask
sed -i 's/^UMASK.*/UMASK 022/' /etc/login.defs 2>/dev/null || true

# repos/packages
rm -f /etc/yum.repos.d/exam3.repo

# logrotate
rm -f /etc/logrotate.d/exam3

# rsyslog
rm -f /etc/rsyslog.d/exam3_local0.conf
systemctl restart rsyslog 2>/dev/null || true

# autofs
systemctl disable autofs 2>/dev/null || true
systemctl stop autofs 2>/dev/null || true
rm -f /etc/auto.remote
sed -i '/\/remote\/docs/d' /etc/auto.master 2>/dev/null || true

echo "[BREAK] autofs removed" | tee -a "$LOG"

echo "[$(date)] Mock Exam 3: Break complete." | tee -a "$LOG"
