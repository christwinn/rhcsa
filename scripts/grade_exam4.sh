#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 4 GRADE SCRIPT
# Title: All Core Objectives + Software, Scripting, GRUB
# ============================================================

PASS=0
FAIL=0
SCORE=0

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash break_exam4.sh). Snapshot your VM first."
  exit 1
fi

pass() { echo "  [PASS] $1"; SCORE=$((SCORE+$2)); PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=============================================="
echo " RHCSA Mock Exam 4: Core + Software/Scripting/GRUB"
echo " $(date)"
echo "=============================================="

# Check 1: root (5 pts)
LOCK=$(passwd -S root 2>/dev/null | awk '{print $2}')
MAXD=$(chage -l root 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
if [[ "$LOCK" != "L" && "$MAXD" != "1" && "$MAXD" != "0" ]]; then
    pass "Root unlocked" 5
else
    fail "Root locked or forced to expire"
fi

# Check 2: users/groups (6 pts)
if id -u admin1 &>/dev/null && \
   [ "$(id -u admin1)" == "3000" ] && \
   [ "$(id -g admin1)" == "$(getent group admins | cut -d: -f3)" ] && \
   [ "$(getent group admins | cut -d: -f3)" == "4500" ] && \
   [ "$(getent group users | cut -d: -f3)" == "4501" ] && \
   id admin1 | grep -q users && id -u user01 &>/dev/null && \
   [ "$(id -u user01)" == "3001" ] && \
   [ "$(id -g user01)" == "$(getent group users | cut -d: -f3)" ] && \
   passwd -S user01 2>/dev/null | awk '{print $2}' | grep -q L; then
    pass "Users/groups configured" 7
else
    fail "Users/groups misconfigured"
fi

# Check 3: password aging/sudo (5 pts)
AGING_OK=0
SUDO_OK=0
MAX_D=$(chage -l admin1 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
MIN_D=$(chage -l admin1 2>/dev/null | grep "Minimum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
WARN_D=$(chage -l admin1 2>/dev/null | grep "Number of days of warning" | awk -F': ' '{print $2}' | tr -d ' ')
if [ "$MAX_D" == "120" ] && [ "$MIN_D" == "10" ] && [ "$WARN_D" == "21" ]; then
    AGING_OK=1
fi
if [ -f /etc/sudoers.d/admin1 ] && \
   [ "$(stat -c %a /etc/sudoers.d/admin1)" == "440" ] && \
   grep -q "admin1" /etc/sudoers.d/admin1 && \
   grep -q "ALL=(ALL)" /etc/sudoers.d/admin1 && \
   grep -q "NOPASSWD" /etc/sudoers.d/admin1; then
    SUDO_OK=1
fi
if [ "$AGING_OK" -eq 1 ] && [ "$SUDO_OK" -eq 1 ]; then
    pass "Password aging/sudo configured" 5
else
    fail "sudo or password aging wrong"
fi

# Check 4: permissions (5 pts)
if [ -d /collab/exam4 ] && \
   [ "$(stat -c %a /collab/exam4)" == "2770" ] && \
   [ -d /collab/tmp ] && \
   [ "$(stat -c %a /collab/tmp)" == "1777" ] && \
   [ -f /usr/local/bin/exam4_exec ] && \
   [ "$(stat -c %a /usr/local/bin/exam4_exec)" == "4750" ]; then
    pass "Permissions and special bits configured" 5
else
    fail "permissions wrong"
fi

# Check 5: ACLs (5 pts)
if [ -d /confidential/exam4 ] && \
   getfacl /confidential/exam4 2>/dev/null | grep -q "^user:admin1:" && \
   getfacl /confidential/exam4 2>/dev/null | grep -q "^default:user:admin1:"; then
    pass "ACLs configured" 5
else
    fail "ACLs missing"
fi

# Check 6: LVM and swap (6 pts)
if pvs 2>/dev/null | grep -q -E "/dev/sdb1|/dev/vdb1" && \
   vgs 2>/dev/null | grep -q vg_exam4 && \
   lvs 2>/dev/null | grep -q "lv_data" && \
   findmnt -n /mnt/data &>/dev/null && \
   lsblk $(swapon --show --noheadings | cut -d' ' -f1) | grep -q "lv_swap"; then 
   #swapon -s | grep -q lv_swap; then
    pass "LVM and swap configured" 6
else
    fail "LVM/swap not configured"
fi

# Check 7: LV extend and label (5 pts)
VG_FREE=$(vgs --noheadings --units m -o vg_free vg_exam4 2>/dev/null | tr -d ' ' || echo "0")
if awk -v free="$VG_FREE" 'BEGIN { exit !(free < 200) }' 2>/dev/null && \
   grep -q "LABEL=EXAM4_DATA" /etc/fstab; then
    pass "LV extended and labeled" 5
else
    fail "LV/label wrong"
fi

# Check 8: NFS/autofs (6 pts)
if grep -q nfsserver.example.com:/exports/exam4 /etc/fstab && \
   grep -q "/remote/exam4" /etc/auto.master 2>/dev/null && \
   systemctl is-active autofs &>/dev/null; then
    pass "NFS and autofs configured" 6
else
    fail "NFS/autofs missing"
fi

# Check 9: SELinux (8 pts)
MODE=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
if [[ "$MODE" == "enforcing" && -d /webapp ]] && \
    ls -lZd /webapp 2>/dev/null | awk '{print $4}' | grep -q "httpd_sys_content_t" && \
    getsebool httpd_can_network_connect 2>/dev/null | grep -q "on" && \
    getsebool httpd_can_sendmail 2>/dev/null | grep -q "on" && \
    semanage port -l 2>/dev/null | grep "http_port_t" | grep -q "8090"; then
    pass "SELinux configured" 9
else
    fail "SELinux misconfigured"
fi

# Check 10: firewalld (5 pts)
if systemctl is-active firewalld &>/dev/null && \
   firewall-cmd --list-services --permanent | grep -qE "http|https|ssh|smtp" && \
   firewall-cmd --list-ports --permanent | grep -q "8090/tcp"; then
    pass "firewalld configured" 5
else
    fail "firewalld misconfigured"
fi

# Check 11: systemd/services (5 pts)
TARGET=$(systemctl get-default 2>/dev/null || echo "")
if [[ "$TARGET" == "multi-user.target" ]] && \
   systemctl is-active httpd sshd chronyd crond &>/dev/null; then
    pass "systemd/services configured" 5
else
    fail "target=$TARGET or services not active"
fi

# Check 12: cron/at/timer (6 pts)
if crontab -l 2>/dev/null | grep -q "report.sh" && \
   atq 2>/dev/null | grep -q "send_alert.sh" && \
   [ -x /usr/local/bin/report.sh ] && \
   systemctl is-enabled exam4.timer &>/dev/null; then
    pass "cron/at/timer configured" 6
else
    fail "cron/at/timer missing"
fi

# Check 13: network (5 pts)
HOST=$(hostnamectl --static 2>/dev/null || echo "")
IP=$(ip addr show 2>/dev/null | grep "192.168.40.40/24" || echo "")
if [[ "$HOST" == "server4.example.com" && -n "$IP" ]]; then
    pass "Network configured" 5
else
    fail "hostname=$HOST, ip=$IP"
fi

# Check 14: software/repos (5 pts)
if [ -f /etc/yum.repos.d/exam4.repo ] && \
   grep -qi "baseos" /etc/yum.repos.d/exam4.repo && \
   rpm -q httpd bash-completion tmux nfs-utils &>/dev/null && \
   systemctl is-active chronyd &>/dev/null; then
    pass "Software and repos configured" 5
else
    fail "software/repos missing"
fi

# Check 15: script (5 pts)
if [ -x /usr/local/bin/disk_usage.sh ] && \
   /usr/local/bin/disk_usage.sh / &>/dev/null; then
    pass "disk_usage.sh configured" 5
else
    fail "script missing"
fi

# Check 16: logrotate/GRUB (6 pts)
if [ -f /etc/logrotate.d/exam4 ] && \
   grubby --info=DEFAULT 2>/dev/null | grep -q "audit=1" && \
   grubby --info=DEFAULT 2>/dev/null | grep -q "quiet"; then
    pass "logrotate and GRUB configured" 6
else
    fail "logrotate/GRUB missing"
fi

# Check 17: chrony/rsyslog (6 pts)
if grep -q "pool.ntp.org" /etc/chrony.conf 2>/dev/null && \
   [ -f /etc/rsyslog.d/exam4.conf ]; then
    pass "chrony and rsyslog configured" 6
else
    fail "chrony/rsyslog missing"
fi

# Check 18: swap file and tuned (4 pts)
if [ -f /swapfile ] && \
   swapon -s | grep -q /swapfile && \
   tuned-adm active 2>/dev/null | grep -q "balanced"; then
    pass "swap file and tuned configured" 4
else
    fail "swap/tuned missing"
fi

echo ""
echo "=============================================="
echo " RESULTS: $PASS/18 checks passed"
echo " SCORE:   $SCORE / 100"
echo "=============================================="
if [[ $SCORE -ge 70 ]]; then
    echo " *** MOCK EXAM 4 PASSED ***"
else
    echo " *** MOCK EXAM 4 FAILED ***"
fi
