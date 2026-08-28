#!/bin/bash
# see learnrhcsa.com for the original
# ============================================================
# RHCSA EX200 - MOCK EXAM 1 GRADE SCRIPT
# Title: All Core Objectives
# ============================================================

PASS=0
FAIL=0
SCORE=0

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo bash grade_exam1.sh)."
  exit 1
fi

pass() { echo "  [PASS] $1"; SCORE=$((SCORE+$2)); PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=============================================="
echo " RHCSA Mock Exam 1: All Core Objectives"
echo " $(date)"
echo "=============================================="

# Check 1: root (5 pts)
LOCK=$(passwd -S root 2>/dev/null | awk '{print $2}')
MAXD=$(chage -l root 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
# L is used indicate Locked, ref: man passwd
if [[ "$LOCK" != "L" && "$MAXD" != "1" && "$MAXD" != "0" ]]; then
    pass "Root unlocked" 6
else
    fail "Root locked or forced to expire"
fi

# Check 2: users/groups (6 pts)
if id -u candidate1 &>/dev/null && \
   [ "$(id -u candidate1)" == "2000" ] && \
   [ "$(id -g candidate1)" == "$(getent group rhcsaadmins | cut -d: -f3)" ] && \
   [ "$(getent group rhcsaadmins | cut -d: -f3)" == "4000" ] && \
   [ "$(getent group rhcsausers | cut -d: -f3)" == "4001" ] && \
   id candidate1 | grep -q rhcsausers && \
   id -u candidate2 &>/dev/null && \
   [ "$(id -u candidate2)" == "2001" ] && \
   [ "$(id -g candidate2)" == "$(getent group rhcsausers | cut -d: -f3)" ] && \
   # changed LK to L as per man page for passwd
   passwd -S candidate2 2>/dev/null | awk '{print $2}' | grep -q "L"; then
    pass "Users/groups configured" 7
else
    fail "Users/groups misconfigured"
fi

# Check 3: password aging/home (5 pts)
HOME_OK=0
AGING_OK=0
if [ -d /home/candidate1 ] && \
   [ "$(stat -c %a /home/candidate1)" == "700" ] && \
   # in task 2 we create the user with primary group rhcsaadmins, candidate1 as a group is never created
   [ "$(stat -c %U:%G /home/candidate1)" == "candidate1:rhcsaadmins" ]; then
    HOME_OK=1
fi
MAX_D=$(chage -l candidate1 2>/dev/null | grep "Maximum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
MIN_D=$(chage -l candidate1 2>/dev/null | grep "Minimum number of days" | awk -F': ' '{print $2}' | tr -d ' ')
WARN_D=$(chage -l candidate1 2>/dev/null | grep "Number of days of warning" | awk -F': ' '{print $2}' | tr -d ' ')
if [ "$MAX_D" == "60" ] && [ "$MIN_D" == "5" ] && [ "$WARN_D" == "10" ]; then
    AGING_OK=1
fi
if [ "$HOME_OK" -eq 1 ] && [ "$AGING_OK" -eq 1 ]; then
    pass "Password aging/home directory correct" 6
else
    fail "home dir or password aging wrong"
fi

# Check 4: shared dir and umask (6 pts)
if [ -d /shared/exam1 ] && \
   [ "$(stat -c %a /shared/exam1)" == "2770" ] && \
   [ "$(stat -c %U:%G /shared/exam1)" == "root:rhcsausers" ] && \
   [ -d /shared/tmp ] && \
   [ "$(stat -c %a /shared/tmp)" == "1777" ] && \
   (  grep -q "^UMASK.*0027" /etc/login.defs || \
      # if we read profile and basrc headers they warn not to update those file so updating those files should be a fail?
      #grep -q "umask 0027" /etc/profile || \
      #grep -q "umask 0027" /etc/bashrc || \
      # following on we are advised to place a custom script in profile.d so: 
      grep -q "umask 0027" /etc/profile.d/*.sh
   ); then
    pass "/shared/exam1 and umask configured" 7
else
    fail "/shared/exam1, /shared/tmp, or umask wrong"
fi

# Check 5: ACLs (6 pts)
if [ -d /private/exam1 ] && \
     getfacl /private/exam1 2>/dev/null | grep -q "^user:candidate1:" && \
     getfacl /private/exam1 2>/dev/null | grep -q "^default:user:candidate1:"; then
    pass "/private/exam1 ACLs configured" 7
else
    fail "ACLs missing"
fi

# Check 6: LVM and swap (8 pts)
# solid or virtual disk
if pvs 2>/dev/null | grep -qE "/dev/sdb1|/dev/vdb1" && \
   vgs 2>/dev/null | grep -q vg_exam1 && \
   lvs 2>/dev/null | grep -q "lv_data" && \
   findmnt -n /mnt/data &>/dev/null && \
   # swapon returns /dev/dm-X this gives no pointer to whether we used lv_swap or sdb2
   lsblk $(swapon --show --noheadings | cut -d' ' -f1) | grep -qE "lv_swap|sdb2|vdb2"; then
   #swapon -s | grep -qE "lv_swap|sdb2"; then
    pass "LVM and swap configured" 9
else
    fail "LVM/swap not configured"
fi

# Check 7: LV extend (5 pts)
VG_FREE=$(vgs --noheadings --units m -o vg_free vg_exam1 2>/dev/null | tr -d ' ' || echo "0")
if awk -v free="$VG_FREE" 'BEGIN { exit !(free < 200) }' 2>/dev/null; then
    pass "LV extended" 6
else
    fail "LV not extended"
fi

# Check 8: NFS/autofs (8 pts)
if grep -q nfsserver.example.com:/exports/exam1 /etc/fstab && \
   grep -q "/remote/data" /etc/auto.master 2>/dev/null && \
   systemctl is-active autofs &>/dev/null; then
    pass "NFS and autofs configured" 9
else
    fail "NFS/autofs missing"
fi

# Check 9: SELinux (8 pts)
MODE=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
if [[ "$MODE" == "enforcing" && -d /web ]] && \
    # ls -Zd = system_u:object_r:httpd_sys_content_t:s0 /web
    # so $4 is blank!
    ls -Zd /web 2>/dev/null | awk '{print $1}' | grep -q "httpd_sys_content_t" && \
    getsebool httpd_can_network_connect 2>/dev/null | grep -q "on" && \
    semanage port -l 2>/dev/null | grep "http_port_t" | grep -q "8080"; then
    pass "SELinux configured" 9
else
    fail "SELinux misconfigured"
fi

# Check 10: firewalld (6 pts)
if systemctl is-active firewalld &>/dev/null && \
   firewall-cmd --list-services --permanent | grep -qE "http|https|ssh" && \
   firewall-cmd --list-ports --permanent | grep -q "8080/tcp"; then
    pass "firewalld configured" 7
else
    fail "firewalld misconfigured"
fi

# Check 11: systemd/services (6 pts)
TARGET=$(systemctl get-default 2>/dev/null || echo "")
if [[ "$TARGET" == "multi-user.target" ]] && \
   systemctl is-active httpd sshd chronyd &>/dev/null; then
    pass "systemd/services configured" 7
else
    fail "target=$TARGET or services not active"
fi

# Check 12: cron/at (6 pts)
if crontab -l 2>/dev/null | grep -q "backup_etc.sh" && \
   # atq 2>/dev/null | grep -q "notify.sh" && \
   # atq does not give up the script name
   # maybe we queued a few jobs, each job will count notify.sh once(1) if it is there.
   # so if notify.sh exists so will 1, 
   # if we have notify.sh in the queue but shh.sh after then would fail but below works around that
   echo $(for i in $(atq | cut -f1); do at -c $i | grep -c "notify.sh"; done) | grep 1 && \
   [ -x /usr/local/bin/backup_etc.sh ]; then
    pass "cron/at/scripts configured" 7
else
    fail "cron/at/scripts missing"
fi

# Check 13: network (6 pts)
HOST=$(hostnamectl --static 2>/dev/null || echo "")
IP=$(ip addr show 2>/dev/null | grep "192.168.10.10/24" || echo "")
if [[ "$HOST" == "server1.example.com" && -n "$IP" ]]; then
    pass "Network configured" 7
else
    fail "hostname=$HOST, ip=$IP"
fi

# Check 14: software/kernel (5 pts)
if [ -f /etc/yum.repos.d/exam1.repo ] && \
   grep -qi "baseos" /etc/yum.repos.d/exam1.repo && \
   rpm -q httpd bash-completion tmux &>/dev/null && \
   tuned-adm active 2>/dev/null | grep -q "virtual-guest" && \
   sysctl -n vm.swappiness 2>/dev/null | grep -q "10"; then
    pass "software/kernel tuned" 6
else
    fail "software/kernel misconfigured"
fi

echo ""
echo "=============================================="
echo " RESULTS: $PASS/14 checks passed"
echo " SCORE:   $SCORE / 100"
echo "=============================================="
if [[ $SCORE -ge 70 ]]; then
    echo " *** MOCK EXAM 1 PASSED ***"
else
    echo " *** MOCK EXAM 1 FAILED ***"
fi
