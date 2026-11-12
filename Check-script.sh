#!/bin/bash
# System Diagnostics Automation Script for Lab Assignment
# Generates a detailed report in /tmp/system_diagnostics.txt

REPORT="/tmp/system_diagnostics.txt"
echo "=== SYSTEM DIAGNOSTICS REPORT ===" > "$REPORT"
echo "Timestamp: $(date)" >> "$REPORT"
echo "Hostname: $(hostname)" >> "$REPORT"
echo "----------------------------------------" >> "$REPORT"

# 1. NETWORK & DNS VERIFICATION
echo "Checking Connectivity & DNS..." >> "$REPORT"
ping -c 2 8.8.8.8 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  - External IP Connection: OK" >> "$REPORT"
else
    echo "  - ALERT!: No external IP routing. Check routing tables using 'ip route'." >> "$REPORT"
fi

nslookup google.com >/dev/null 2>&1 || host google.com >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  - DNS Resolution: OK" >> "$REPORT"
else
    echo "  - ALERT!: DNS Failure. Check /etc/resolv.conf permissions and attributes." >> "$REPORT"
fi

# 2. CRITICAL FILE PERMISSIONS VERIFICATION
echo "Checking Key System File Permissions..." >> "$REPORT"
for target_file in /bin/ls /bin/cat /etc/passwd /etc/shadow /etc/sudoers; do
    if [ -e "$target_file" ]; then
        perms=$(stat -c "%a" "$target_file")
        owner=$(stat -c "%U:%G" "$target_file")
        echo "  - $target_file -> Permissions: $perms | Owner: $owner" >> "$REPORT"
        
        # Specific flag for the breaker script's action
        if [ "$target_file" == "/etc/sudoers" ] && [ "$perms" == "777" ]; then
            echo "    -> CRITICAL: /etc/sudoers is 777. Sudo execution is fundamentally broken." >> "$REPORT"
        fi
    fi
done

# 3. DISK SPACE STORAGE CHECK
echo "Checking Disk Space Capacity..." >> "$REPORT"
root_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
echo "  - Root (/) Utilization: ${root_usage}%" >> "$REPORT"
if [ "$root_usage" -gt 90 ]; then
    echo "    -> ALERT!: Disk usage is critical (>90%)." >> "$REPORT"
    echo "    -> Large dummy files detected in /var/log or /tmp:" >> "$REPORT"
    find /var/log /tmp -type f -size +100M -exec ls -lh {} \; 2>/dev/null >> "$REPORT"
fi

# 4. BOOT INTEGRITY CHECK (GRUB & FSTAB)
echo "Analyzing Boot and Mount Structures..." >> "$REPORT"
if grep -q "broken-" /boot/grub/grub.cfg 2>/dev/null || grep -q "broken-" /boot/grub2/grub.cfg 2>/dev/null; then
    echo "  - CRITICAL: Corrupted UUID entries ('broken-') flagged inside GRUB configurations." >> "$REPORT"
fi

if grep -q "errors=panic" /etc/fstab 2>/dev/null; then
    echo "  - WARNING: /etc/fstab contains aggressive 'errors=panic' flags." >> "$REPORT"
fi

echo "----------------------------------------" >> "$REPORT"
echo "Diagnostics finished. Results written to: $REPORT"
