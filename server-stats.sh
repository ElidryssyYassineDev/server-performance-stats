#!/usr/bin/env bash

# Server Performance Stats
# A Linux system resource reporting tool.

set -o pipefail

check_dependencies() {
    local missing=()
    local cmd

    # Check required external commands
    for cmd in awk ps df hostname who sleep head; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    # Report missing commands
    if ((${#missing[@]} > 0)); then
        printf 'Error: missing commands: %s\n' "${missing[*]}" >&2
        return 1
    fi

    # Check required Linux system files
    local file

    for file in /proc/stat /proc/meminfo /proc/loadavg \
                /proc/uptime /etc/os-release; do
        if [[ ! -r "$file" ]]; then
            printf 'Error: cannot read %s\n' "$file" >&2
            return 1
        fi
    done

    return 0
}


get_system_info() {
    local os_name
    local host_name
    local uptime_seconds
    local days hours minutes
    local load_1 load_5 load_15
    local sessions

    # Operating system and hostname
    . /etc/os-release
    os_name=$PRETTY_NAME
    host_name=$(hostname)

    # Read uptime in seconds
    read -r uptime_seconds _ < /proc/uptime
    uptime_seconds=${uptime_seconds%.*}

    days=$((uptime_seconds / 86400))
    hours=$((uptime_seconds % 86400 / 3600))
    minutes=$((uptime_seconds % 3600 / 60))

    # Read load averages
    read -r load_1 load_5 load_15 _ < /proc/loadavg

    # Read logged-in sessions
    sessions=$(who)

    # Display system information
    echo
    echo "SYSTEM INFORMATION"
    echo "----------------------------------"
    printf "Operating System: %s\n" "$os_name"
    printf "Hostname:         %s\n" "$host_name"
    printf "Uptime:           %d days, %d hours, %d minutes\n" \
        "$days" "$hours" "$minutes"
    printf "Load Average:     %s (1m), %s (5m), %s (15m)\n" \
        "$load_1" "$load_5" "$load_15"

    echo "Logged-in Users:"
    if [[ -n "$sessions" ]]; then
        printf '%s\n' "$sessions"
    else
        echo "  No login sessions reported"
    fi
}

get_cpu_usage() {
    local sample1 sample2
    local total1 idle1 total2 idle2
    local delta_total delta_idle

    # Take the first CPU sample
    sample1=$(awk '/^cpu / {
        total = 0
        for (i = 2; i <= 9; i++) {
            total += $i
        }
        idle = $5 + $6
        printf "%.0f %.0f\n", total, idle
        exit
    }' /proc/stat) || return 1

    # Wait one second between samples
    sleep 1

    # Take the second CPU sample
    sample2=$(awk '/^cpu / {
        total = 0
        for (i = 2; i <= 9; i++) {
            total += $i
        }
        idle = $5 + $6
        printf "%.0f %.0f\n", total, idle
        exit
    }' /proc/stat) || return 1

    # Extract total and idle counters
    read -r total1 idle1 <<< "$sample1"
    read -r total2 idle2 <<< "$sample2"

    # Calculate differences between samples
    delta_total=$((total2 - total1))
    delta_idle=$((idle2 - idle1))

    # Protect against division by zero or invalid counters
    if ((delta_total <= 0 || delta_idle < 0 || delta_idle > delta_total)); then
        printf 'Error: invalid CPU counter measurements\n' >&2
        return 1
    fi

    # Calculate CPU usage percentage
    awk -v total="$delta_total" -v idle="$delta_idle" \
        'BEGIN {
            printf "%.2f", (total - idle) / total * 100
        }'
}

get_memory_usage() {
    local memory_data
    local mem_total mem_available mem_free
    local mem_used

    # Extract memory values from /proc/meminfo
    memory_data=$(awk '
        /^MemTotal:/ {
            total = $2
            found_total = 1
        }
        /^MemAvailable:/ {
            available = $2
            found_available = 1
        }
        /^MemFree:/ {
            free = $2
            found_free = 1
        }
        END {
            if (!found_total || !found_available || !found_free ||
                total <= 0 || available > total || free > total) {
                exit 1
            }

            printf "%d %d %d\n", total, available, free
        }
    ' /proc/meminfo) || {
        printf 'Error: unable to read memory statistics\n' >&2
        return 1
    }

    # Parse and validate the extracted values
    read -r mem_total mem_available mem_free <<< "$memory_data"

    [[ "$mem_total" =~ ^[0-9]+$ &&
       "$mem_available" =~ ^[0-9]+$ &&
       "$mem_free" =~ ^[0-9]+$ ]] || {
        printf 'Error: invalid memory statistics\n' >&2
        return 1
    }

    mem_used=$((mem_total - mem_available))

    # Linux reports these values in KiB; divide by 1024 for MiB
    awk -v total="$mem_total" \
        -v available="$mem_available" \
        -v free="$mem_free" \
        -v used="$mem_used" '
        BEGIN {
            printf "Total Memory:     %.2f MiB\n", total / 1024
            printf "Used Memory:      %.2f MiB (%.2f%%)\n",
                   used / 1024, used / total * 100
            printf "Available Memory: %.2f MiB (%.2f%%)\n",
                   available / 1024, available / total * 100
            printf "Free Memory:      %.2f MiB\n", free / 1024
        }
    '
}

get_disk_usage() {
    local filesystem total used available usage mount_point

    # Retrieve statistics for the root filesystem
    read -r filesystem total used available usage mount_point < <(
        df -P / | awk 'NR == 2 {
            print $1, $2, $3, $4, $5, $6
        }'
    ) || return 1

    # Validate that the returned values are usable
    if [[ -z "$filesystem" || -z "$total" || -z "$used" ||
          -z "$available" || -z "$usage" ]]; then
        printf 'Error: unable to retrieve disk statistics\n' >&2
        return 1
    fi

    # Display disk statistics in GB
    awk -v total="$total" \
        -v used="$used" \
        -v available="$available" \
        -v usage="$usage" \
        -v filesystem="$filesystem" \
        -v mount_point="$mount_point" '
        BEGIN {
            printf "Filesystem:       %s\n", filesystem
            printf "Mount Point:      %s\n", mount_point
            printf "Total Disk:       %.2f GB\n", total / 1024 / 1024
            printf "Used Disk:        %.2f GB (%s)\n",
                   used / 1024 / 1024, usage
            printf "Available Disk:   %.2f GB\n",
                   available / 1024 / 1024
        }
    '
}

get_top_cpu_processes() {
    printf "%-8s %-12s %-8s %-8s %s\n" \
        "PID" "USER" "%CPU" "%MEM" "COMMAND"

    ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu |
        awk '
            NR >= 2 && NR <= 6 {
                command = $5
                for (i = 6; i <= NF; i++) {
                    command = command " " $i
                }

                printf "%-8s %-12s %-8s %-8s %s\n",
                       $1, $2, $3, $4, command
            }
        '
}

get_top_memory_processes() {
    printf "%-8s %-12s %-8s %-8s %s\n" \
        "PID" "USER" "%CPU" "%MEM" "COMMAND"

    ps -eo pid,user,%cpu,%mem,comm --sort=-%mem |
        awk '
            NR >= 2 && NR <= 6 {
                command = $5
                for (i = 6; i <= NF; i++) {
                    command = command " " $i
                }

                printf "%-8s %-12s %-8s %-8s %s\n",
                       $1, $2, $3, $4, command
            }
        '
}

main() {

    check_dependencies || return 1

    echo "=================================="
    echo "       SERVER PERFORMANCE STATS"
    echo "=================================="

    get_system_info

    echo
    echo "CPU USAGE"
    echo "----------------------------------"

    local cpu_usage
    cpu_usage=$(get_cpu_usage) || return 1

    printf "Total CPU Usage : %s%%\n" "$cpu_usage"

    echo
    echo "MEMORY USAGE"
    echo "----------------------------------"

    get_memory_usage || return 1

    echo
    echo "DISK USAGE"
    echo "----------------------------------"

    get_disk_usage || return 1

    echo
    echo "TOP 5 PROCESSES BY CPU"
    echo "----------------------------------"
    get_top_cpu_processes

    echo
    echo "TOP 5 PROCESSES BY MEMORY"
    echo "----------------------------------"
    get_top_memory_processes
}

main
