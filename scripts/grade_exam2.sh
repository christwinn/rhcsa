#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 2 GRADE SCRIPT
# Title: Security, Containers, and Scripting
# ============================================================

PASS=0
FAIL=0
SCORE=0

pass() { echo "  [PASS] $1"; SCORE=$((SCORE+$2)); PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=============================================="
echo " RHCSA Mock Exam 2: Security, Containers, Scripting"
echo " $(date)"
echo "=============================================="

# Check 1: root (5 pts)
LOCK=$(passwd -S root 2>/dev/null | awk '{print $2}')
MAXD=$(chage -l root 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
if [[ "$LOCK" != "L" && "$MAXD" != "1" && "$MAXD" != "0" ]]; then
    pass "Root unlocked" 6
else
    fail "Root locked or forced to expire"
fi

# Check 2: users/groups (6 pts)
if id -u op1 &>/dev/null && \
   [ "$(id -u op1)" == "2500" ] && \
   [ "$(id -g op1)" == "$(getent group sysadmins | cut -d: -f3)" ] && \
   [ "$(getent group sysadmins | cut -d: -f3)" == "3500" ] && \
   [ "$(getent group operators | cut -d: -f3)" == "3501" ] && \
   id op1 | grep -q operators && \
   id -u op2 &>/dev/null && \
   [ "$(id -u op2)" == "2501" ] && \
   [ "$(id -g op2)" == "$(getent group operators | cut -d: -f3)" ] && \
   passwd -S op2 2>/dev/null | awk '{print $2}' | grep -q L; then
    pass "Users/groups configured" 7
else
    fail "Users/groups misconfigured"
fi

# Check 3: password aging/sudo (5 pts)
AGING_OK=0
SUDO_OK=0
MAX_D=$(chage -l op1 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
MIN_D=$(chage -l op1 2>/dev/null | grep "Minimum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
WARN_D=$(chage -l op1 2>/dev/null | grep "Number of days of warning" | awk -F': ' '{print $2}' | tr -d ' ')
if [ "$MAX_D" == "90" ] && [ "$MIN_D" == "7" ] && [ "$WARN_D" == "14" ]; then
    AGING_OK=1
fi
if [ -f /etc/sudoers.d/op1 ] && \
   [ "$(stat -c %a /etc/sudoers.d/op1)" == "440" ] && \
   grep -q "op1" /etc/sudoers.d/op1 && \
   grep -q "ALL=(ALL)" /etc/sudoers.d/op1 && \
   grep -q "NOPASSWD" /etc/sudoers.d/op1; then
    SUDO_OK=1
fi
if [ "$AGING_OK" -eq 1 ] && \
   [ "$SUDO_OK" -eq 1 ]; then
    pass "Password aging/sudo configured" 6
else
    fail "sudo or password aging wrong"
fi

# Check 4: permissions/SUID (5 pts)
if [ -d /srv/exam2 ] && \
   [ "$(stat -c %a /srv/exam2)" == "2770" ] && \
   [ -f /usr/local/bin/exam2_cmd ] && \
   [ "$(stat -c %a /usr/local/bin/exam2_cmd)" == "4750" ]; then
    pass "Permissions and SUID configured" 5
else
    fail "permissions wrong"
fi

# Check 5: ACLs (5 pts)
if [ -d /audit/exam2 ] && \
   getfacl /audit/exam2 2>/dev/null | grep -q "^user:op1:" && \
   getfacl /audit/exam2 2>/dev/null | grep -q "^default:user:op1:"; then
    pass "ACLs configured" 5
else
    fail "ACLs missing"
fi

# Check 6: LVM and swap (6 pts)
if pvs 2>/dev/null | grep -qE "/dev/sdb1|/dev/vdb1" && \
   vgs 2>/dev/null | grep -q vg_exam2 && \
   lvs 2>/dev/null | grep -q "lv_app" && \
   findmnt -n /mnt/app &>/dev/null && \
   lsblk $(swapon --show --noheadings | cut -d' ' -f1) | grep -qE "lv_swap"; then
   # swapon -s | grep -q lv_swap; then retruns /dev/dm-X
    pass "LVM and swap configured" 7
else
    fail "LVM/swap not configured"
fi

# Check 7: LV extend and NFS (5 pts)
VG_FREE=$(vgs --noheadings --units m -o vg_free vg_exam2 2>/dev/null | tr -d ' ' || echo "0")
if awk -v free="$VG_FREE" 'BEGIN { exit !(free < 200) }' 2>/dev/null && \
   grep -q nfsserver.example.com:/exports/exam2 /etc/fstab; then
    pass "LV extended and NFS configured" 5
else
    fail "LV/NFS wrong"
fi

# Check 8: autofs (5 pts)
if systemctl is-active autofs &>/dev/null && \
   grep -q "/remote/users" /etc/auto.master 2>/dev/null; then
    pass "autofs configured" 5
else
    fail "autofs missing"
fi

# Check 9: SELinux (8 pts)
MODE=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
if [[ "$MODE" == "enforcing" && -d /app ]] && \
   ls -lZd /app 2>/dev/null | awk '{print $5}' | grep -q "httpd_sys_content_t" && \
   getsebool httpd_can_network_connect 2>/dev/null | grep -q "on" && \
   getsebool httpd_can_network_relay 2>/dev/null | grep -q "on" && \
   semanage port -l 2>/dev/null | grep "http_port_t" | grep -q "8443"; then
    pass "SELinux configured" 9
else
    fail "SELinux misconfigured"
fi

# Check 10: firewalld (6 pts)
if systemctl is-active firewalld &>/dev/null && \
   firewall-cmd --list-services --permanent | grep -qE "http|https|ssh|smtp" && \
   firewall-cmd --list-ports --permanent | grep -q "8443/tcp" && \
   firewall-cmd --list-ports --permanent | grep -q "8081/tcp"; then
    pass "firewalld configured" 7
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
if crontab -l 2>/dev/null | grep -q "archive_logs.sh" && \
   # atq 2>/dev/null | grep -q "notify.sh" && \
   echo $(for i in $(atq | cut -f1); do at -c $i | grep -c "notify.sh"; done) | grep -q "1" && \
   [ -x /usr/local/bin/archive_logs.sh ] && \
   systemctl is-enabled exam2.timer &>/dev/null; then
    pass "cron/at/timer configured" 7
else
    fail "cron/at/timer missing"
fi

# Check 13: network (5 pts)
HOST=$(hostnamectl --static 2>/dev/null || echo "")
IP=$(ip addr show 2>/dev/null | grep "192.168.20.20/24" || echo "")
if [[ "$HOST" == "server2.example.com" && -n "$IP" ]]; then
    pass "Network configured" 5
else
    fail "hostname=$HOST, ip=$IP"
fi

# Check 14: container (8 pts)
if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^systemd-exam2-web$" && \
   [ -f /etc/containers/systemd/exam2-web.container ]; then
     pass "systemd Podman container configured" 9
else if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^exam2-web$" && \
   systemctl is-enabled container-exam2-web &>/dev/null; then
     pass "Podman container configured" 9
else
     fail "Container missing"
fi fi

#if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^exam2-web$" && \
#   systemctl is-enabled container-exam2-web &>/dev/null; then
#    pass "Podman container configured" 9
#else
#    fail "container missing"
#fi

# Check 15: script (6 pts)
if [ -x /usr/local/bin/check_users.sh ] && \
   /usr/local/bin/check_users.sh op1 2>/dev/null | grep -q "EXIST" && \
   /usr/local/bin/check_users.sh missinguser 2>/dev/null | grep -q "MISSING"; then
    pass "check_users.sh configured" 7
else
    fail "script missing or wrong output"
fi

# Check 16: logging/journald (5 pts)
if [ -d /var/log/journal ] && [ -f /etc/rsyslog.d/exam2.conf ]; then
    pass "journald/rsyslog configured" 5
else
    fail "logging misconfigured"
fi

echo ""
echo "=============================================="
echo " RESULTS: $PASS/16 checks passed"
echo " SCORE:   $SCORE / 100"
echo "=============================================="
if [[ $SCORE -ge 70 ]]; then
    echo " *** MOCK EXAM 2 PASSED ***"
else
    echo " *** MOCK EXAM 2 FAILED ***"
fi
