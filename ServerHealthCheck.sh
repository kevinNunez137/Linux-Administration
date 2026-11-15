#!/usr/bin/env bash
# ==============================================================================
# SERVER HEALTH MONITOR SCRIPT (CentOS & Ubuntu Compatible)
# Collects CPU, memory, disk, and network metrics and writes a single structured
# JSON report per execution for human readability and dashboard ingestion.
# ==============================================================================

# Exit immediately on command failure, unset variables, or pipeline errors.
set -euo pipefail

# --- Configurable Thresholds & Settings ---
readonly CPU_THRESHOLD=85
readonly MEM_THRESHOLD=85
readonly DISK_THRESHOLD=85
readonly PING_TARGETS=("1.1.1.1" "8.8.8.8" "9.9.9.9")

# Determine a sensible log directory (avoids /tmp; falls back to user state dir).
if [[ -w "/var/log" ]] || mkdir -p "/var/log/server_health" 2>/dev/null; then
    readonly LOG_DIR="/var/log/server_health"
else
    readonly LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/server_health"
    mkdir -p "$LOG_DIR"
fi

# --- Metric Collection Functions ---

# Retrieves the system hostname safely across minimal CentOS and Ubuntu installs.
get_hostname() {
    if [[ -r /proc/sys/kernel/hostname ]]; then
        cat /proc/sys/kernel/hostname
    else
        uname -n
    fi
}

# Measures active CPU usage over a 1-second sample using vmstat (standard on
# both CentOS and Ubuntu procps-ng) and evaluates against CPU_THRESHOLD.
get_cpu_stats() {
    local cpu_pct

    if command -v vmstat >/dev/null 2>&1; then
        # vmstat 1 2 takes two samples 1 second apart; the last line is current load.
        # The 15th column ($15) is idle CPU percentage on both CentOS and Ubuntu.
        cpu_pct=$(vmstat 1 2 | awk 'END { printf "%.2f", 100 - $15 }')
    else
        cpu_pct=$(top -bn1 | awk '/^%?Cpu/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /id,?/) {
                    gsub(/,/, "", $(i-1))
                    printf "%.2f", 100 - $(i-1)
                }
            }
        }')
    fi

    awk -v pct="${cpu_pct:-0}" -v thresh="$CPU_THRESHOLD" '
        BEGIN {
            status = (pct + 0 > thresh) ? "WARNING" : "OK"
            printf "{\"usage_percent\": %.2f, \"threshold\": %d, \"status\": \"%s\"}", pct, thresh, status
        }
    '
}

# Collects memory usage in megabytes across CentOS and Ubuntu free(1) formats.
# Uses available memory ($7) when present for accurate Linux memory reporting.
get_memory_stats() {
    free -m | awk -v thresh="$MEM_THRESHOLD" '
        /^Mem:/ {
            total = $2
            # Modern procps-ng (CentOS 7+, Ubuntu 16.04+) provides "available" in $7.
            if (NF >= 7 && $7 ~ /^[0-9]+$/) {
                used = total - $7
            } else {
                used = $3
            }
            pct = (total > 0) ? (used / total) * 100 : 0
            status = (pct > thresh) ? "WARNING" : "OK"
            printf "{\"used_mb\": %d, \"total_mb\": %d, \"usage_percent\": %.2f, \"threshold\": %d, \"status\": \"%s\"}", used, total, pct, thresh, status
        }
    '
}

# Checks local physical filesystems using POSIX output (-P) and filters out
# virtual/pseudo filesystems (tmpfs, devtmpfs, squashfs, overlay) in awk.
get_disk_stats() {
    df -P -T -h -l | awk -v thresh="$DISK_THRESHOLD" '
        BEGIN { printf "[" }
        NR > 1 && $2 !~ /^(tmpfs|devtmpfs|squashfs|overlay|iso9660)$/ {
            pct = $6
            gsub(/%/, "", pct)
            status = (pct + 0 > thresh) ? "WARNING" : "OK"

            if (count++ > 0) printf ", "
            printf "{\"filesystem\": \"%s\", \"type\": \"%s\", \"mount\": \"%s\", \"usage_percent\": %d, \"threshold\": %d, \"status\": \"%s\"}", $1, $2, $7, pct, thresh, status
        }
        END { printf "]" }
    '
}

# Tests external connectivity across multiple hosts.
# Reports UP as soon as any single target responds.
get_network_status() {
    local target
    local reachable_host=""

    for target in "${PING_TARGETS[@]}"; do
        if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
            reachable_host="$target"
            break
        fi
    done

    if [[ -n "$reachable_host" ]]; then
        printf '{"status": "UP", "reachable_host": "%s"}' "$reachable_host"
    else
        printf '{"status": "DOWN", "reachable_host": null}'
    fi
}

# --- Main Execution ---

main() {
    local timestamp file_stamp hostname report_file
    local cpu_json mem_json disk_json net_json report

    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    file_stamp=$(date -u +"%Y%m%dT%H%M%SZ")
    hostname=$(get_hostname)
    report_file="${LOG_DIR}/health_report_${file_stamp}.json"

    cpu_json=$(get_cpu_stats)
    mem_json=$(get_memory_stats)
    disk_json=$(get_disk_stats)
    net_json=$(get_network_status)

    # Build a single, clean JSON document for this execution.
    report=$(printf '{"timestamp": "%s", "hostname": "%s", "cpu": %s, "memory": %s, "disks": %s, "network": %s}\n' \
        "$timestamp" "$hostname" "$cpu_json" "$mem_json" "$disk_json" "$net_json")

    # Save the report to its own file so historical data is never duplicated.
    # Formats with jq or python3 if available, otherwise writes compact valid JSON.
    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$report" | jq . > "$report_file"
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$report" | python3 -m json.tool > "$report_file"
    else
        printf '%s\n' "$report" > "$report_file"
    fi

    # Output the report and file location to stdout.
    cat "$report_file"
    printf 'Report saved to: %s\n' "$report_file"
}

main "$@"
