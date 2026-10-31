#!/bin/bash

# ==============================================================================
# OUTPUT DIRECTORY CONFIGURATION
# ==============================================================================
# Define the absolute path where the generated audit reports will be stored.
# This satisfies the requirement of not using the temporary directory /tmp.
OUTPUT_DIR="/var/log/security_audits"

# Create the directory configured above if it does not already exist on the system.
# The '-p' flag prevents error messages if the directory is already created.
mkdir -p "$OUTPUT_DIR"

# Generate a timestamp using the format: YearMonthDay_HourMinuteSecond.
# This ensures that every report file has a completely unique and unrepeatable name.
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${OUTPUT_DIR}/audit_${TIMESTAMP}.log"

# Initialize a flag variable to 0 (False).
# This will change to 1 (True) if any security risks or anomalies are detected.
PROBLEM_FOUND=0

# Redirect standard output (stdout) and standard error (stderr) to the log file.
# The 'tee' command writes to the file while displaying it on the screen.
# This is crucial for the script to execute cleanly in the background via cron.
exec > >(tee -ia "$REPORT_FILE") 2>&1

# Start printing the report header containing metadata from the server.
echo "========================================================================"
echo " LINUX SECURITY AUDIT REPORT - $(date)"
echo "========================================================================"
echo "Host: $(hostname)"
echo "OS: $(bash -c 'source /etc/os-release && echo $NAME $VERSION')"
echo "========================================================================"

# ------------------------------------------------------------------------------
# 1. REPORT FAILED SSH LOGINS (LAST 24 HOURS)
# ------------------------------------------------------------------------------
echo -e "\n Failed SSH Logins (Last 24 Hours):"
echo "--------------------------------------------------"

# Use journalctl to fetch sshd logs from the last 24 hours across both OS natively.
# This avoids 'invalid date' parsing errors caused by different OS log styles.
if command -v journalctl >/dev/null 2>&1; then
    journalctl _SYSTEMD_UNIT=ssh.service _SYSTEMD_UNIT=sshd.service --since "24 hours ago" 2>/dev/null | grep -E "Failed|Invalid user" > /tmp/ssh_failed_temp.txt
else
    # Fallback for older systems without systemd/journalctl
    if [ -f /var/log/secure ]; then AUTH_LOG="/var/log/secure"; else AUTH_LOG="/var/log/auth.log"; fi
    grep -E "Failed|Invalid user" "$AUTH_LOG" 2>/dev/null | grep -v "cron" > /tmp/ssh_failed_temp.txt
fi

# Validate if the temporary file contains entries (-s checks that it is not empty).
if [ -s /tmp/ssh_failed_temp.txt ]; then
    cat /tmp/ssh_failed_temp.txt
    # Requirement met: If failed logins are found, mark that a problem exists.
    PROBLEM_FOUND=1
else
    echo "No failed SSH logins detected in the last 24 hours."
fi
# Clean up the temporary file from the system.
rm -f /tmp/ssh_failed_temp.txt

# ------------------------------------------------------------------------------
# 2. AUDIT ACCOUNTS WITH ROOT PRIVILEGES (UID 0) AND EMPTY PASSWORDS
# ------------------------------------------------------------------------------
echo -e "\n Accounts with UID 0 (Root Privileges):"
echo "--------------------------------------------------"
# Analyze the /etc/passwd file. The third field ($3) represents the UID.
# If the UID is 0, it means the account possesses full administrative privileges.
UID_ZERO_ACCOUNTS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
echo "$UID_ZERO_ACCOUNTS"

# Count how many lines (accounts) were returned by the previous command.
NUM_UID_ZERO=$(echo "$UID_ZERO_ACCOUNTS" | wc -l)

# On a secure system, only the default 'root' account should have UID 0.
# If the count is higher than 1, another user has hidden root privileges.
if [ "$NUM_UID_ZERO" -gt 1 ]; then
    PROBLEM_FOUND=1
fi

echo -e "\n Accounts with Empty Passwords:"
echo "--------------------------------------------------"
# Analyze the restricted /etc/shadow file. The second field ($2) holds the password hash.
# If the field is completely empty, the user can log in without a password.
EMPTY_PASS_ACCOUNTS=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null)

# If the variable is not empty, print the vulnerable accounts and trigger the alert.
if [ -n "$EMPTY_PASS_ACCOUNTS" ]; then
    echo "$EMPTY_PASS_ACCOUNTS"
    PROBLEM_FOUND=1
else
    echo "No accounts with empty passwords found."
fi

# ------------------------------------------------------------------------------
# 3. IDENTIFY LISTENING PORTS USING THE SS COMMAND
# ------------------------------------------------------------------------------
echo -e "\n Listening Ports (using ss):"
echo "--------------------------------------------------"
# Execute the modern 'ss' utility as requested by the assignment.
# Flags applied: -t (TCP), -u (UDP), -l (Listening), -n (Numeric ports).
ss -tuln

# ------------------------------------------------------------------------------
# SCRIPT FINALIZATION AND EXIT CODE EVALUATION
# ------------------------------------------------------------------------------
echo -e "\n========================================================================"
echo "Audit complete. Results saved to: $REPORT_FILE"
echo "========================================================================"

# Check if our problem flag was triggered anywhere during the execution.
if [ "$PROBLEM_FOUND" -ne 0 ]; then
    # If a problem was found (failed logins, extra UID 0, or blank passwords), exit with 1.
    exit 1
else
    # If the system is clean and no issues were found, exit successfully with 0.
    exit 0
fi
