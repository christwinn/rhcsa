#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 3 GRADE SCRIPT
# Title: Storage, Networking, and Scripting
# ============================================================

PASS=0
FAIL=0
SCORE=0

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash grade_exam3.sh)."
  exit 1
fi

pass() { echo "  [PASS] $1"; SCORE=$((SCORE+$2)); PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=============================================="
echo " RHCSA Mock Exam 3: Storage, Networking, Scripting"
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
if id -u user1 &>/dev/null && \
   [ "$(id -u user1)" == "2600" ] && \
   [ "$(id -g user1)" == "$(getent group staff | cut -d: -f3)" ] && \
   [ "$(getent group staff | cut -d: -f3)" == "3600" ] && \
   [ "$(getent group students | cut -d: -f3)" == "3601" ] && \
   id user1 | grep -q students && \
   id -u user2 &>/dev/null && \
   [ "$(id -u user2)" == "2601" ] && \
   [ "$(id -g user2)" == "$(getent group students | cut -d: -f3)" ] && \
   passwd -S user2 2>/dev/null | awk '{print $2}' | grep -q L; then
    pass "Users/groups configured" 6
else
    fail "Users/groups misconfigured"
fi

# Check 3: password aging/home (5 pts)
HOME_OK=0
AGING_OK=0
if [ -d /home/user1 ] && \
[ "$(stat -c %a /home/user1)" == "700" ] && \
[ "$(stat -c %U:%G /home/user1)" == "user1:user1" ]; then
    HOME_OK=1
fi
MAX_D=$(chage -l user1 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
MIN_D=$(chage -l user1 2>/dev/null | grep "Minimum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
WARN_D=$(chage -l user1 2>/dev/null | grep "Number of days of warning" | awk -F': ' '{print $2}' | tr -d ' ')
if [ "$MAX_D" == "45" ] && [ "$MIN_D" == "3" ] && [ "$WARN_D" == "7" ]; then
    AGING_OK=1
fi
if [ "$HOME_OK" -eq 1 ] && [ "$AGING_OK" -eq 1 ]; then
    pass "Password aging/home directory correct" 5
else
    fail "home dir or password aging wrong"
fi

# Check 4: permissions/SGID (5 pts)
if [ -d /project/exam3 ] && \
   [ "$(stat -c %a /project/exam3)" == "2770" ] && \
   [ "$(stat -c %U:%G /project/exam3)" == "root:students" ] && \
   grep -q "^UMASK.*0077" /etc/login.defs; then
    pass "Permissions and SGID configured" 5
else
    fail "permissions wrong"
fi

# Check 5: ACLs (5 pts)
if [ -d /restricted/exam3 ] && \
   getfacl /restricted/exam3 2>/dev/null | grep -q "^user:user1:" && \
   getfacl /restricted/exam3 2>/dev/null | grep -q "^default:user:user1:"; then
    pass "ACLs configured" 5
else
    fail "ACLs missing"
fi

# Check 6: LVM and swap (8 pts)
if pvs 2>/dev/null | grep -q /dev/sdb1 && \
   vgs 2>/dev/null | grep -q vg_exam3 && \
   lvs 2>/dev/null | grep -q "lv_docs" && \
   findmnt -n /mnt/docs &>/dev/null && swapon -s | grep -q lv_swap; then
    pass "LVM and swap configured" 9
else
    fail "LVM/swap not configured"
fi

# Check 7: LV extend and label (5 pts)
VG_FREE=$(vgs --noheadings --units m -o vg_free vg_exam3 2>/dev/null | tr -d ' ' || echo "0")
if awk -v free="$VG_FREE" 'BEGIN { exit !(free < 200) }' 2>/dev/null && \
   grep -q "LABEL=EXAM3_DOCS" /etc/fstab; then
    pass "LV extended and labeled" 5
else
    fail "LV/label wrong"
fi

# Check 8: NFS and autofs (8 pts)
if grep -q nfsserver.example.com:/exports/exam3 /etc/fstab && \
   grep -q "/remote/docs" /etc/auto.master 2>/dev/null && \
   systemctl is-active autofs &>/dev/null; then
    pass "NFS and autofs configured" 9
else
    fail "NFS/autofs missing"
fi

# Check 9: SELinux (8 pts)
MODE=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
if [[ "$MODE" == "enforcing" && -d /webdocs ]] && \
   ls -Zd /webdocs 2>/dev/null | awk '{print $4}' | grep -q "httpd_sys_content_t" && \
   getsebool httpd_can_sendmail 2>/dev/null | grep -q "on" && \
   getsebool httpd_use_nfs 2>/dev/null | grep -q "on" && \
   semanage port -l 2>/dev/null | grep "http_port_t" | grep -q "8888"; then
    pass "SELinux configured" 9
else
    fail "SELinux misconfigured"
fi

# Check 10: firewalld (6 pts)
if systemctl is-active firewalld &>/dev/null && \
   firewall-cmd --list-services --permanent | grep -qE "http|https|ssh|nfs" && \
   firewall-cmd --list-ports --permanent | grep -q "8888/tcp"; then
    pass "firewalld configured" 6
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

# Check 12: cron/at (6 pts)
if crontab -l 2>/dev/null | grep -q "cleanup_tmp.sh" && \
   atq 2>/dev/null | grep -q "send_report.sh" && \
   [ -x /usr/local/bin/cleanup_tmp.sh ]; then
    pass "cron/at/scripts configured" 6
else
    fail "cron/at/scripts missing"
fi

# Check 13: network (6 pts)
HOST=$(hostnamectl --static 2>/dev/null || echo "")
IP=$(ip addr show 2>/dev/null | grep "192.168.30.30/24" || echo "")
if [[ "$HOST" == "server3.example.com" && -n "$IP" ]]; then
    pass "Network configured" 6
else
    fail "hostname=$HOST, ip=$IP"
fi

# Check 14: script (6 pts)
if [ -x /usr/local/bin/list_large_files.sh ] && \
   /usr/local/bin/list_large_files.sh /etc &>/dev/null; then
    pass "list_large_files.sh configured" 6
else
    fail "script missing or broken"
fi

# Check 15: logrotate/software (5 pts)
if [ -f /etc/yum.repos.d/exam3.repo ] && \
   rpm -q httpd bash-completion nfs-utils &>/dev/null && \
   [ -f /etc/logrotate.d/exam3 ]; then
    pass "software/logrotate configured" 5
else
    fail "software/logrotate missing"
fi

# Check 16: text processing/log analysis (7 pts)
if [ -f /tmp/exam3_denied.txt ] && \
   [ -f /etc/rsyslog.d/exam3_local0.conf ]; then
    pass "text processing and logging configured" 8
else
    fail "text processing/logging missing"
fi

echo ""
echo "=============================================="
echo " RESULTS: $PASS/16 checks passed"
echo " SCORE:   $SCORE / 100"
echo "=============================================="
if [[ $SCORE -ge 70 ]]; then
    echo " *** MOCK EXAM 3 PASSED ***"
else
    echo " *** MOCK EXAM 3 FAILED ***"
fi
