#!/bin/bash
#
# security_audit.sh
#
# Author: Kevin Nunez
#
# Description:
#   Basic Linux security audit script designed to run on both
#   Ubuntu and CentOS without modification.
#
# Features:
#   - Reports failed SSH login attempts.
#   - Lists accounts with root privileges (UID 0).
#   - Identifies accounts with empty passwords.
#   - Displays listening ports using ss.
#   - Saves results to a timestamped report file.
#   - Compatible with cron jobs.
#   - Does not modify system settings.
#   - Returns a non-zero exit code when problems are found.
#

#########################################
# CONFIGURATION
#########################################

# Directory where reports will be stored.
# This directory is NOT located in /tmp as required.
REPORT_DIR="/var/log/security_reports"

#########################################
# INITIALIZATION
#########################################

# Create the report directory if it does not exist.
mkdir -p "$REPORT_DIR"

# Generate a timestamp for the report filename.
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Define the output report file.
REPORT_FILE="${REPORT_DIR}/security_report_${TIMESTAMP}.txt"

# Flag used to determine whether issues were found.
PROBLEM_FOUND=0

#########################################
# GENERATE REPORT
#########################################

{
    echo "========================================"
    echo "          SECURITY AUDIT REPORT"
    echo "========================================"
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo

    #########################################
    # FAILED SSH LOGIN ATTEMPTS
    #########################################

    echo "========================================"
    echo "FAILED SSH LOGIN ATTEMPTS"
    echo "========================================"

    FAILED_COUNT=0

    # Ubuntu/Debian authentication log
    if [ -f /var/log/auth.log ]; then

        grep "Failed password" /var/log/auth.log

        FAILED_COUNT=$(grep -c "Failed password" /var/log/auth.log)

    # CentOS/RHEL authentication log
    elif [ -f /var/log/secure ]; then

        grep "Failed password" /var/log/secure

        FAILED_COUNT=$(grep -c "Failed password" /var/log/secure)

    else
        echo "Authentication log file not found."
    fi

    echo
    echo "Failed SSH Login Count: $FAILED_COUNT"
    echo

    if [ "$FAILED_COUNT" -gt 0 ]; then
        PROBLEM_FOUND=1
    fi

    #########################################
    # ACCOUNTS WITH UID 0
    #########################################

    echo "========================================"
    echo "ACCOUNTS WITH ROOT PRIVILEGES (UID 0)"
    echo "========================================"

    UID0_COUNT=0

    while IFS=: read -r username password uid gid comment home shell
    do
        if [ "$uid" -eq 0 ]; then
            echo "$username"
            UID0_COUNT=$((UID0_COUNT + 1))
        fi
    done < /etc/passwd

    echo

    # More than one UID 0 account is considered suspicious.
    if [ "$UID0_COUNT" -gt 1 ]; then
        PROBLEM_FOUND=1
    fi

    #########################################
    # ACCOUNTS WITH EMPTY PASSWORDS
    #########################################

    echo "========================================"
    echo "ACCOUNTS WITH EMPTY PASSWORDS"
    echo "========================================"

    EMPTY_PASSWORD_FOUND=0

    if [ -r /etc/shadow ]; then

        while IFS=: read -r username password rest
        do
            if [ -z "$password" ]; then
                echo "$username"
                EMPTY_PASSWORD_FOUND=1
            fi
        done < /etc/shadow

    else
        echo "Cannot read /etc/shadow. Run the script as root."
    fi

    echo

    if [ "$EMPTY_PASSWORD_FOUND" -eq 1 ]; then
        PROBLEM_FOUND=1
    fi

    #########################################
    # LISTENING PORTS
    #########################################

    echo "========================================"
    echo "LISTENING PORTS"
    echo "========================================"

    ss -tuln

    echo
    echo "========================================"
    echo "END OF REPORT"
    echo "========================================"

} | tee "$REPORT_FILE"

#########################################
# SUMMARY
#########################################

echo "Report saved to:"
echo "$REPORT_FILE"

#########################################
# EXIT STATUS
#########################################

# Requirement:
# Return a non-zero exit code when a problem is found.

if [ "$PROBLEM_FOUND" -eq 1 ]; then
    exit 1
else
    exit 0
fi
