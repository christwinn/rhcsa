#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 5 GRADE SCRIPT
# Title: Full Comprehensive Simulation
# ============================================================

PASS=0
FAIL=0
SCORE=0

pass() { echo "  [PASS] $1"; SCORE=$((SCORE+$2)); PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=============================================="
echo " RHCSA Mock Exam 5: Full Simulation"
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

# Check 2: users/groups/sudo (6 pts)
if id -u examuser1 &>/dev/null && \
   [ "$(id -u examuser1)" == "1900" ] && \
   [ "$(id -g examuser1)" == "$(getent group examusers | cut -d: -f3)" ] && \
   [ "$(getent group examusers | cut -d: -f3)" == "3000" ] && \
   id examuser1 | grep -q examusers && \
   id -u examuser2 &>/dev/null && [ "$(id -u examuser2)" == "1901" ] && \
   passwd -S examuser2 2>/dev/null | awk '{print $2}' | grep -q L && \
   [ -f /etc/sudoers.d/examuser1 ] && \
   [ "$(stat -c %a /etc/sudoers.d/examuser1)" == "440" ] && \
   grep -q "examuser1" /etc/sudoers.d/examuser1 && \
   grep -q "ALL=(ALL)" /etc/sudoers.d/examuser1 && \
   grep -q "NOPASSWD" /etc/sudoers.d/examuser1; then
    pass "Users/groups/sudo configured" 5
else
    fail "examuser1/examusers/sudo misconfigured"
fi

# Check 3: password aging and home (5 pts)
HOME_OK=0
AGING_OK=0
if [ -d /home/examuser1 ] && \
   [ "$(stat -c %a /home/examuser1)" == "700" ] && \
   [ "$(stat -c %U:%G /home/examuser1)" == "examuser1:examusers" ]; then
    HOME_OK=1
fi
MAX_D=$(chage -l examuser1 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
MIN_D=$(chage -l examuser1 2>/dev/null | grep "Minimum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
WARN_D=$(chage -l examuser1 2>/dev/null | grep "Number of days of warning" | awk -F': ' '{print $2}' | tr -d ' ')
if [ "$MAX_D" == "90" ] && [ "$MIN_D" == "7" ] && [ "$WARN_D" == "14" ]; then
    AGING_OK=1
fi
if [ "$HOME_OK" -eq 1 ] && [ "$AGING_OK" -eq 1 ]; then
    pass "Password aging/home directory correct" 5
else
    fail "home dir or password aging wrong"
fi

# Check 4: shared directory (5 pts)
if [ -d /data/exam ] && \
   [ "$(stat -c %a /data/exam)" == "2770" ] && \
   [ "$(stat -c %U:%G /data/exam)" == "root:examusers" ]; then
    pass "/data/exam configured" 5
else
    fail "/data/exam wrong"
fi

# Check 5: ACLs (5 pts)
if [ -d /secure/exam ] && \
   getfacl /secure/exam 2>/dev/null | grep -q "^user:examuser1:" && \
   getfacl /secure/exam 2>/dev/null | grep -q "^default:user:examuser1:"; then
    pass "/secure/exam ACLs configured" 5
else
    fail "ACLs missing"
fi

# Check 6: LVM (6 pts)
if pvs 2>/dev/null | grep -q -E "/dev/sdb1|/dev/vdb1" && 
   vgs 2>/dev/null | grep -q vg_final && \
   lvs 2>/dev/null | grep -q "lv_final" && 
   findmnt -n /mnt/final &>/dev/null; then
    pass "LVM configured" 5
else
    fail "LVM not configured"
fi

# Check 7: LV extend and swap (6 pts)
VG_FREE=$(vgs --noheadings --units m -o vg_free vg_final 2>/dev/null | tr -d ' ' || echo "0")
if awk -v free="$VG_FREE" 'BEGIN { exit !(free < 200) }' 2>/dev/null && \
   [ -b /dev/vg_final/lv_swap ] && \
   lsblk $(swapon --show --noheadings | cut -d' ' -f1) | grep -q "lv_swap"; then
   # swapon -s | grep -q lv_swap; then
    pass "LV extended and swap active" 5
else
    fail "LV/swap not configured"
fi

# Check 8: NFS and labeled mount (5 pts)
if grep -q nfsserver.example.com:/exports/exam5 /etc/fstab && \
   findmnt -n /mnt/labeled &>/dev/null; then
    pass "NFS and labeled mount configured" 5
else
    fail "NFS/labeled mount missing"
fi

# Check 9: autofs (5 pts)
if systemctl is-active autofs &>/dev/null && \
   grep -q "/remote/exam" /etc/auto.master 2>/dev/null; then
    pass "autofs configured" 5
else
    fail "autofs missing"
fi

# Check 10: SELinux (6 pts)
MODE=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
if [[ "$MODE" == "enforcing" && -d "/web" ]] && \
    ls -lZd /web 2>/dev/null | awk '{print $5}' | grep -q "httpd_sys_content_t" && \
    getsebool httpd_can_network_connect 2>/dev/null | grep -q "on" && \
    semanage port -l 2>/dev/null | grep "http_port_t" | grep -q "8443"; then
    pass "SELinux configured" 5
else
    fail "SELinux misconfigured"
fi

# Check 11: firewalld (5 pts)
FIREWALL_OK=1
for PORT in 8080 8081 8443; do
  if ! firewall-cmd --list-ports --permanent 2>/dev/null | grep -qE "(^|[[:space:]])${PORT}/tcp([[:space:]]|$)"; then
    FIREWALL_OK=0
  fi
done
if ! firewall-cmd --list-services --permanent 2>/dev/null | grep -qE "(^|[[:space:]])(http|https)([[:space:]]|$)"; then
  FIREWALL_OK=0
fi
if systemctl is-active firewalld &>/dev/null && [ "$FIREWALL_OK" -eq 1 ]; then
    pass "firewalld configured" 5
else
    fail "firewalld misconfigured"
fi

# Check 12: httpd and container (6 pts)
if systemctl is-active httpd &>/dev/null; then
   # setup as systemd unit files
   if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^systemd-examweb$" && \
      [ -f /etc/containers/systemd/exam2-web.container ]; then
        pass "systemd Podman container configured" 5
   # set up as seperate service 
   else if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^examweb$" && \
      systemctl is-enabled container-examweb &>/dev/null; then  
        pass "Podman container configured" 5
   else
        fail "httpd configured/container misconfigured"    
   fi fi
else 
    fail "httpd misconfigured"
fi

# Check 13: SSH/network (6 pts)
HOST=$(hostnamectl --static 2>/dev/null || echo "")
IP=$(ip addr show 2>/dev/null | grep "192.168.30.30/24" || echo "")
AUTH=$(sshd -T 2>/dev/null | grep "^passwordauthentication" | awk '{print $2}')
ROOT=$(sshd -T 2>/dev/null | grep "^permitrootlogin" | awk '{print $2}')
if [[ "$HOST" == "server5.example.com" && -n "$IP" && "$AUTH" == "yes" && "$ROOT" == "no" ]]; then
    pass "SSH/network configured" 5
else
    fail "hostname=$HOST, ip=$IP, passwordauthentication=$AUTH, permitrootlogin=$ROOT"
fi

# Check 14: services/target (5 pts)
TARGET=$(systemctl get-default 2>/dev/null || echo "")
if [[ "$TARGET" == "multi-user.target" ]] && \
   systemctl is-active httpd sshd chronyd crond firewalld &>/dev/null && \
   systemctl is-enabled httpd sshd chronyd crond firewalld &>/dev/null; then
    pass "Services and target configured" 5
else
    fail "target=$TARGET or services not enabled/active"
fi

# Check 15: time/logging/kernel (6 pts)
if grep -q "pool.ntp.org" /etc/chrony.conf 2>/dev/null && \
   [ -f /etc/rsyslog.d/exam_secure.conf ] && \
   sysctl -n kernel.randomize_va_space 2>/dev/null | grep -q "2" && \
   [ -d /var/log/journal ]; then
    pass "time/logging/kernel configured" 5
else
    fail "time/logging/kernel missing"
fi

# Check 16: cron/at/timer (6 pts)
if crontab -l 2>/dev/null | grep -q "exam_backup" && \
   atq 2>/dev/null | grep -q "exam_alert" && \
   systemctl is-enabled exam.timer &>/dev/null; then
    pass "cron/at/timer configured" 5
else
    fail "cron/at/timer missing"
fi

# Check 17: repo/packages (5 pts)
if [ -f /etc/yum.repos.d/exam5.repo ] && \
   grep -qi "baseos" /etc/yum.repos.d/exam5.repo && \
   grep -qi "appstream" /etc/yum.repos.d/exam5.repo && \
   rpm -q httpd bash-completion tmux nfs-utils &>/dev/null; then
    pass "repo/packages configured" 5
else
    fail "repo/packages missing"
fi

# Check 18: tuned/logrotate (5 pts)
if systemctl is-active tuned &>/dev/null && \
   tuned-adm active 2>/dev/null | grep -q "virtual-guest" && \
   [ -f /etc/logrotate.d/exam5 ]; then
    pass "tuned/logrotate configured" 5
else
    fail "tuned/logrotate missing"
fi

# Check 19: script (5 pts)
if [ -x /usr/local/bin/disk_usage.sh ] && \
   /usr/local/bin/disk_usage.sh / &>/dev/null; then
    pass "disk_usage.sh configured" 5
else
    fail "disk_usage.sh missing"
fi

# Check 20: rich rule (6 pts)
if firewall-cmd --list-rich-rules --permanent | grep -q "192.168.30.0/24"; then
    pass "firewalld rich rule configured" 5
else
    fail "rich rule missing"
fi

echo ""
echo "=============================================="
echo " RESULTS: $PASS/20 checks passed"
echo " SCORE:   $SCORE / 100"
echo "=============================================="
if [[ $SCORE -ge 70 ]]; then
    echo " *** MOCK EXAM 5 PASSED ***"
else
    echo " *** MOCK EXAM 5 FAILED ***"
fi
