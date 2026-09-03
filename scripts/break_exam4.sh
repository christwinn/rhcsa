#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 4 BREAK SCRIPT
# Title: All Core Objectives + Software, Scripting, GRUB
# Difficulty: 4/5
# Time Limit: 180 minutes
# Tasks: 18
# ============================================================
# Run as root. Snapshot before running.
# ============================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash break_exam4.sh). Snapshot your VM first."
  exit 1
fi
LOG="/var/log/rhcsa_mock_exam4.log"
echo "[$(date)] Mock Exam 4: All Core + Software/Scripting/GRUB - Break started" | tee "$LOG"

# Lock root
passwd -l root || true
chage -M 1 -m 1 -W 0 root 2>/dev/null || true
rm -f /.autorelabel

echo "[BREAK] Root locked" | tee -a "$LOG"

# Users/groups
for u in admin1 user01; do id "$u" &>/dev/null && userdel -r "$u" 2>/dev/null || true; done
for g in admins users; do getent group "$g" && groupdel "$g" 2>/dev/null || true; done
rm -f /etc/sudoers.d/admin1

echo "[BREAK] Users/groups/sudo removed" | tee -a "$LOG"

# Directories
rm -rf /collab /confidential /webapp /usr/local/bin/exam4_exec

echo "[BREAK] Directories removed" | tee -a "$LOG"

# Storage
if [ -b /dev/sdb ]; then
    wipefs -a /dev/sdb 2>/dev/null || true
    vgremove -y vg_exam4 2>/dev/null || true
    pvremove -y /dev/sdb1 2>/dev/null || true
    parted -s /dev/sdb mklabel msdos 2>/dev/null || true
fi
umount -f /mnt/data /mnt/nfs 2>/dev/null || true
sed -i '/\/mnt\/data/d; /\/mnt\/nfs/d' /etc/fstab 2>/dev/null || true
rm -rf /mnt/data
if [ -b /dev/vg_exam4/lv_swap ]; then
    swapoff /dev/vg_exam4/lv_swap 2>/dev/null || true
    lvremove -y vg_exam4/lv_swap 2>/dev/null || true
fi

echo "[BREAK] Storage removed" | tee -a "$LOG"

# SELinux
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
setsebool -P httpd_can_network_connect 0 2>/dev/null || true
setsebool -P httpd_can_sendmail 0 2>/dev/null || true
semanage port -d -t http_port_t -p tcp 8090 2>/dev/null || true

echo "[BREAK] SELinux reset" | tee -a "$LOG"

# Firewalld
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
for x in http https ssh smtp; do firewall-cmd --remove-service="$x" --permanent 2>/dev/null || true; done
firewall-cmd --remove-port=8090/tcp --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "[BREAK] firewalld disabled" | tee -a "$LOG"

# systemd/services
systemctl set-default graphical.target 2>/dev/null || true
for svc in httpd sshd chronyd crond; do
    systemctl disable "$svc" 2>/dev/null || true
    systemctl stop "$svc" 2>/dev/null || true
done

echo "[BREAK] systemd/services reset" | tee -a "$LOG"

# scripts, cron, at, timer
rm -f /usr/local/bin/report.sh /usr/local/bin/send_alert.sh /usr/local/bin/disk_usage.sh
rm -f /etc/systemd/system/exam4.timer /etc/systemd/system/exam4.service
atq 2>/dev/null | awk '{print $1}' | xargs -r atrm 2>/dev/null || true
 crontab -l 2>/dev/null | grep -v report.sh | crontab - 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

echo "[BREAK] scripts/timers/cron removed" | tee -a "$LOG"

# Network
IFACE=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | head -n1 | cut -d: -f1)
if [[ -n "$IFACE" ]]; then
    nmcli connection down "$IFACE" 2>/dev/null || true
    nmcli connection delete "$IFACE" 2>/dev/null || true
fi
hostnamectl set-hostname broken4.example.com 2>/dev/null || true
sed -i '/192.168.40.40/d' /etc/hosts 2>/dev/null || true

echo "[BREAK] network reset" | tee -a "$LOG"

# umask
sed -i 's/^UMASK.*/UMASK 022/' /etc/login.defs 2>/dev/null || true

# repos/packages
rm -f /etc/yum.repos.d/exam4.repo

# logrotate
rm -f /etc/logrotate.d/exam4

# GRUB
sed -i 's/quiet audit=1//' /etc/default/grub 2>/dev/null || true
if command -v grub2-mkconfig >/dev/null 2>&1; then
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
fi

echo "[BREAK] GRUB reset" | tee -a "$LOG"

# rsyslog
rm -f /etc/rsyslog.d/exam4.conf
systemctl restart rsyslog 2>/dev/null || true

# chrony
sed -i 's/^pool.*/# pool removed/' /etc/chrony.conf 2>/dev/null || true

# swap file
if [ -f /swapfile ]; then
    swapoff /swapfile 2>/dev/null || true
    rm -f /swapfile
fi
sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true

# tuned
systemctl stop tuned 2>/dev/null || true
systemctl disable tuned 2>/dev/null || true

# autofs
systemctl disable autofs 2>/dev/null || true
systemctl stop autofs 2>/dev/null || true
rm -f /etc/auto.remote
sed -i '/\/remote\/exam4/d' /etc/auto.master 2>/dev/null || true

echo "[BREAK] autofs removed" | tee -a "$LOG"

echo "[$(date)] Mock Exam 4: Break complete." | tee -a "$LOG"
