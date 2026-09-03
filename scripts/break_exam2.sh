#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 2 BREAK SCRIPT
# Title: Security, Containers, and Scripting
# Difficulty: 3/5
# Time Limit: 150 minutes
# Tasks: 16
# ============================================================
# Run as root. Snapshot before running.
# ============================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash break_exam2.sh). Snapshot your VM first."
  exit 1
fi
LOG="/var/log/rhcsa_mock_exam2.log"
echo "[$(date)] Mock Exam 2: Security, Containers, Scripting - Break started" | tee "$LOG"

# Lock root
passwd -l root || true
chage -M 1 -m 1 -W 0 root 2>/dev/null || true
rm -f /.autorelabel

echo "[BREAK] Root locked" | tee -a "$LOG"

# Users/groups
for u in op1 op2; do id "$u" &>/dev/null && userdel -r "$u" 2>/dev/null || true; done
for g in sysadmins operators; do getent group "$g" && groupdel "$g" 2>/dev/null || true; done
rm -f /etc/sudoers.d/op1

echo "[BREAK] Users/groups/sudo removed" | tee -a "$LOG"

# Directories
rm -rf /srv/exam2 /audit/exam2 /app /backup

echo "[BREAK] Directories removed" | tee -a "$LOG"

# Storage
if [ -b /dev/sdb ]; then
    wipefs -a /dev/sdb 2>/dev/null || true
    vgremove -y vg_exam2 2>/dev/null || true
    pvremove -y /dev/sdb1 2>/dev/null || true
    parted -s /dev/sdb mklabel msdos 2>/dev/null || true
fi
umount -f /mnt/app /mnt/nfs 2>/dev/null || true
sed -i '/\/mnt\/app/d; /\/mnt\/nfs/d' /etc/fstab 2>/dev/null || true
rm -rf /mnt/app
if [ -b /dev/vg_exam2/lv_swap ]; then
    swapoff /dev/vg_exam2/lv_swap 2>/dev/null || true
    lvremove -y vg_exam2/lv_swap 2>/dev/null || true
fi

echo "[BREAK] Storage removed" | tee -a "$LOG"

# SELinux
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
setsebool -P httpd_can_network_connect 0 2>/dev/null || true
setsebool -P httpd_can_network_relay 0 2>/dev/null || true
semanage port -d -t http_port_t -p tcp 8443 2>/dev/null || true

echo "[BREAK] SELinux reset" | tee -a "$LOG"

# Firewalld
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
for x in http https ssh smtp; do firewall-cmd --remove-service="$x" --permanent 2>/dev/null || true; done
for p in 8443/tcp 8081/tcp; do firewall-cmd --remove-port="$p" --permanent 2>/dev/null || true; done
firewall-cmd --reload 2>/dev/null || true

echo "[BREAK] firewalld disabled" | tee -a "$LOG"

# systemd/services/target
systemctl set-default graphical.target 2>/dev/null || true
for svc in httpd sshd chronyd crond; do
    systemctl disable "$svc" 2>/dev/null || true
    systemctl stop "$svc" 2>/dev/null || true
done

echo "[BREAK] systemd target/services reset" | tee -a "$LOG"

# scripts, cron, at, timer
rm -f /usr/local/bin/archive_logs.sh /usr/local/bin/notify.sh /usr/local/bin/check_users.sh /usr/local/bin/exam2_cmd
rm -f /etc/systemd/system/exam2.timer /etc/systemd/system/exam2.service
atq 2>/dev/null | awk '{print $1}' | xargs -r atrm 2>/dev/null || true
 crontab -l 2>/dev/null | grep -v archive_logs | crontab - 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

echo "[BREAK] scripts/timers/cron removed" | tee -a "$LOG"

# Network
IFACE=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | head -n1 | cut -d: -f1)
if [[ -n "$IFACE" ]]; then
    nmcli connection down "$IFACE" 2>/dev/null || true
    nmcli connection delete "$IFACE" 2>/dev/null || true
fi
hostnamectl set-hostname broken2.example.com 2>/dev/null || true
sed -i '/192.168.20.20/d' /etc/hosts 2>/dev/null || true

echo "[BREAK] network reset" | tee -a "$LOG"

# umask
sed -i 's/^UMASK.*/UMASK 022/' /etc/login.defs 2>/dev/null || true

# journald
rm -rf /var/log/journal

# rsyslog
rm -f /etc/rsyslog.d/exam2.conf
systemctl restart rsyslog 2>/dev/null || true

# Podman/container
systemctl disable container-exam2-web 2>/dev/null || true
systemctl stop container-exam2-web 2>/dev/null || true
podman rm -f exam2-web 2>/dev/null || true
podman rmi -a 2>/dev/null || true
rm -f /etc/systemd/system/container-exam2-web.service

echo "[BREAK] container removed" | tee -a "$LOG"

# autofs
systemctl disable autofs 2>/dev/null || true
systemctl stop autofs 2>/dev/null || true
rm -f /etc/auto.remote
sed -i '/\/remote\/users/d' /etc/auto.master 2>/dev/null || true

echo "[BREAK] autofs removed" | tee -a "$LOG"

echo "[$(date)] Mock Exam 2: Break complete." | tee -a "$LOG"
