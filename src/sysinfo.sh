#!/bin/bash
# src/sysinfo.sh
# System information collectors and capability detection.

# Ensure core is available if run standalone (optional guard)
if [[ -z "${NC:-}" ]]; then
    # We assume this is sourced from main.sh so core should be there.
    # But for safety/testing, we can try to source it relative to this file.
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/core.sh" ]]; then
        source "$SCRIPT_DIR/core.sh"
    fi
fi

# ==========================================
# 1. Capability & OS Detection
# ==========================================

# Exports: SYS_DISTRO, SYS_PM, SYS_AUR, CAPABILITY_MATRIX
declare -A CAPABILITY_MATRIX

detect_capabilities() {
    log_verbose "Detecting system capabilities..."
    
    if [ -f /etc/os-release ]; then
        # Use a subshell or carefully source to avoid polluting globals too much,
        # but we need ID.
        local ID
        # shellcheck source=/dev/null
        source /etc/os-release
        SYS_DISTRO="$ID"
    else
        log_error "Cannot detect OS (no /etc/os-release)."
        return 1
    fi

    log_verbose "Detected OS ID: $SYS_DISTRO"

    # Identify Package Manager & Family
    SYS_AUR=""
    case "$SYS_DISTRO" in
        ubuntu|debian|kali|pop|linuxmint)
            SYS_PM="apt"
            ;;
        fedora|rhel|centos|nobara)
            SYS_PM="dnf"
            ;;
        arch|manjaro|endeavouros)
            SYS_PM="pacman"
            if check_cmd yay; then SYS_AUR="yay"; fi
            if check_cmd paru; then SYS_AUR="paru"; fi
            ;;
        *)
            log_warn "Unsupported distribution family: $SYS_DISTRO"
            SYS_PM="unknown"
            ;;
    esac

    # Build Capability Matrix
    # Format: "plugin:method" -> "source"
    
    # ZSH
    CAPABILITY_MATRIX["zsh"]="$SYS_PM"
    
    # Starship
    if [[ "$SYS_PM" == "pacman" ]]; then
        CAPABILITY_MATRIX["starship"]="pacman"
    else
        CAPABILITY_MATRIX["starship"]="script"
    fi

    # Autosuggestions, Syntax Highlighting
    # Simplified logic from original script
    case "$SYS_PM" in
        apt|pacman|dnf)
           CAPABILITY_MATRIX["zsh-autosuggestions"]="$SYS_PM"
           CAPABILITY_MATRIX["zsh-syntax-highlighting"]="$SYS_PM"
           ;;
        *)
           CAPABILITY_MATRIX["zsh-autosuggestions"]="git"
           CAPABILITY_MATRIX["zsh-syntax-highlighting"]="git"
           ;;
    esac
    
    # Autocomplete (Usually Git)
    CAPABILITY_MATRIX["zsh-autocomplete"]="git"
}

# ==========================================
# 2. Resource Utilisation Collectors
# ==========================================

# CPU Usage
# Returns integer percentage (0-100)
# Note: This sleeps for 0.1s to measure diff.
get_cpu_usage() {
    read -r cpu a b c idle rest < /proc/stat
    local total=$((a+b+c+idle))
    local idle_prev=$idle
    local total_prev=$total
    
    sleep 0.1
    
    read -r cpu a b c idle rest < /proc/stat
    total=$((a+b+c+idle))
    local total_diff=$((total - total_prev))
    local idle_diff=$((idle - idle_prev))
    
    if [ "$total_diff" -eq 0 ]; then
        echo "0"
    else
        echo "$((100 * (total_diff - idle_diff) / total_diff))"
    fi
}

# Memory Usage
# Returns float percentage (e.g. 45.2)
get_mem_usage() {
    free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}'
}

# Swap Usage
# Returns float percentage
get_swap_usage() {
    free | grep Swap | awk '{if ($2>0) printf "%.1f", $3/$2 * 100; else print "0"}'
}

# Disk Usage
# Usage: get_disk_usage "/mountpoint"
# Returns integer percentage
get_disk_usage() {
    local target="${1:-/}"
    df "$target" | tail -1 | awk '{print $5}' | tr -d '%'
}

# Load Average
# Returns "1min 5min 15min"
get_load_avg() {
    awk '{print $1, $2, $3}' /proc/loadavg
}

# Battery Info
# Returns percentage or "N/A"
get_battery_info() {
    if [ -d /sys/class/power_supply/BAT0 ]; then
        cat /sys/class/power_supply/BAT0/capacity
    elif [ -d /sys/class/power_supply/BAT1 ]; then
        cat /sys/class/power_supply/BAT1/capacity
    else
        echo "N/A"
    fi
}

# Top Processes
# Returns formatted string
get_top_processes() {
    # Comm, CPU, MEM. Sort by CPU desc. Take top 5.
    ps -eo comm:15,%cpu,%mem --sort=-%cpu | head -n 6 | tail -n 5 | awk '{printf "%-15s CPU:%s%% MEM:%s%%", $1, $2, $3}'
}

# ==========================================
# 3. Network Collectors (Stateful)
# ==========================================

# Globals for network calculations
RX_PREV=0
TX_PREV=0

# Initialize network counters
sysinfo_net_init() {
    read -r RX_PREV TX_PREV <<< "$(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev)"
}

# Get Network Usage
# Returns: "RX_KB TX_KB" (integers)
get_net_usage() {
    local RX_NOW TX_NOW
    read -r RX_NOW TX_NOW <<< "$(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev)"
    
    local rx_diff=$((RX_NOW - RX_PREV))
    local tx_diff=$((TX_NOW - TX_PREV))
    
    RX_PREV=$RX_NOW
    TX_PREV=$TX_NOW
    
    echo "$((rx_diff / 1024)) $((tx_diff / 1024))"
}

# Get IP Address (Primary)
get_ip_address() {
    ip -c addr show | grep -v 127.0.0.1 | grep inet | head -n 1 | awk '{print $2}' | cut -d/ -f1
}
