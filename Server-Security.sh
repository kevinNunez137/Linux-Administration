#!/bin/bash

# ==============================================================================
# OUTPUT DIRECTORY CONFIGURATION
# ==============================================================================
#
# The Lines that the AI made going to say AI, the Lines that i put going to say ME.
# Define the absolute path where the generated audit reports will be stored.AI
# This satisfies the requirement of not using the temporary directory /tmp.AI
# In this line next in this code, is going to make a different folders inside folder for create
# a unique log file.ME
OUTPUT_DIR="/var/log/security_audits"

# Create the directory configured above if it does not already exist on the system.AI
# The '-p' flag prevents error messages if the directory is already created.AI
# This Prevent we not going to see the same directory.ME
mkdir -p "$OUTPUT_DIR"

# Generate a timestamp using the format: YearMonthDay_HourMinuteSecond.AI
# This ensures that every report file has a completely unique and unrepeatable name.AI
# I saw this code in Intro to Linux with Penta, the %Y=is Year,%=Is the Month,%D=is the day.
# %H= is the hour,%M= is the minutes,%S= is the Seconds. The TimeStamp & Report_file are the
# variables, with the output and the timestamp.log we can make a unique file of log.ME
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${OUTPUT_DIR}/audit_${TIMESTAMP}.log"

# Initialize a flag variable to 0 (False).AI
# This will change to 1 (True) if any security risks or anomalies are detected.AI
PROBLEM_FOUND=0

# Redirect standard output (stdout) and standard error (stderr) to the log file.AI
# The 'tee' command writes to the file while displaying it on the screen.AI
# This is crucial for the script to execute cleanly in the background via cron.AI
exec > >(tee -ia "$REPORT_FILE") 2>&1

# Start printing the report header containing metadata from the server.AI
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

# Detect the OS distribution. CentOS/RHEL logs auth events in '/var/log/secure'.AI
# Ubuntu/Debian stores authentication logs in '/var/log/auth.log'.AI
if [ -f /var/log/secure ]; then
    AUTH_LOG="/var/log/secure"
elif [ -f /var/log/auth.log ]; then
    AUTH_LOG="/var/log/auth.log"
else
    AUTH_LOG=""
fi

# If a valid authentication log file was found on the current system:AI
if [ -n "$AUTH_LOG" ]; then
    # Use 'awk' to process the log efficiently and compatibly across both OS.
    # d: Calculates the exact date and time from 24 hours ago.
    awk -v d="$(date -d '24 hours ago' +'%b %e %H:%M:%S')" '
        BEGIN { 
            # Get the UNIX timestamp in seconds from 24 hours ago.
            "date -d \"24 hours ago\" +%s" | getline ts_limit 
        }
        {
            # Convert the timestamp of the current log line into UNIX seconds.
            "date -d \"" $1 " " $2 " " $3 "\" +%s" | getline ts_log
            
            # If the log event occurred within the last 24 hours:
            if (ts_log >= ts_limit) {
                # Look for common patterns of failed SSH attempts.
                if ($0 ~ /sshd.*Failed/ || $0 ~ /sshd.*Invalid user/) {
                    print $0
                }
            }
        }
    ' "$AUTH_LOG" > /tmp/ssh_failed_temp.txt

    # Validate if the temporary file contains entries (-s checks that it is not empty).AI
    if [ -s /tmp/ssh_failed_temp.txt ]; then
        cat /tmp/ssh_failed_temp.txt
        # Requirement met: If failed logins are found, mark that a problem exists.AI
        PROBLEM_FOUND=1
    else
        echo "No failed SSH logins detected in the last 24 hours."
    fi
    # Clean up the temporary file from the system.AI
    rm -f /tmp/ssh_failed_temp.txt
else
    echo "Error: Authentication log file not found."
fi

# ------------------------------------------------------------------------------
# 2. AUDIT ACCOUNTS WITH ROOT PRIVILEGES (UID 0) AND EMPTY PASSWORDS
# ------------------------------------------------------------------------------
echo -e "\n Accounts with UID 0 (Root Privileges):"
echo "--------------------------------------------------"
# Analyze the /etc/passwd file. The third field ($3) represents the UID.AI
# If the UID is 0, it means the account possesses full administrative privileges.AI
UID_ZERO_ACCOUNTS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
echo "$UID_ZERO_ACCOUNTS"

# Count how many lines (accounts) were returned by the previous command.AI
NUM_UID_ZERO=$(echo "$UID_ZERO_ACCOUNTS" | wc -l)

# On a secure system, only the default 'root' account should have UID 0.AI
# If the count is higher than 1, another user has hidden root privileges.AI
if [ "$NUM_UID_ZERO" -gt 1 ]; then
    PROBLEM_FOUND=1
fi

echo -e "\n Accounts with Empty Passwords:"
echo "--------------------------------------------------"
# Analyze the restricted /etc/shadow file. The second field ($2) holds the password hash.AI
# If the field is completely empty, the user can log in without a password.AI
EMPTY_PASS_ACCOUNTS=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null)

# If the variable is not empty, print the vulnerable accounts and trigger the alert.AI
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
# Execute the modern 'ss' utility as requested by the assignment.AI
# Flags applied: -t (TCP), -u (UDP), -l (Listening), -n (Numeric ports).AI
ss -tuln

# ------------------------------------------------------------------------------
# SCRIPT FINALIZATION AND EXIT CODE EVALUATION
# ------------------------------------------------------------------------------
echo -e "\n========================================================================"
echo "Audit complete. Results saved to: $REPORT_FILE"
echo "========================================================================"

# Check if our problem flag was triggered anywhere during the execution.AI
if [ "$PROBLEM_FOUND" -ne 0 ]; then
    # If a problem was found (failed logins, extra UID 0, or blank passwords), exit with 1.AI
    exit 1
else
    # If the system is clean and no issues were found, exit successfully with 0.AI
    exit 0
fi
