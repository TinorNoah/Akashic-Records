#!/bin/bash

# Colors and Styles
# Foreground
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

# Styles
BOLD=$(tput bold)
DIM=$(tput dim)
RESET=$(tput sgr0)
REVERSE=$(tput rev)

# Hide cursor and clear screen
tput civis
clear

# Cleanup function to restore cursor and clear screen on exit
cleanup() {
    tput cnorm
    tput sgr0
    clear
    exit 0
}
trap cleanup SIGINT SIGTERM

# Function to get color based on percentage
# Usage: get_color <percentage>
get_color() {
    local percent=$1
    if (( $(echo "$percent >= 80" | bc -l) )); then
        echo -e "$RED"
    elif (( $(echo "$percent >= 50" | bc -l) )); then
        echo -e "$YELLOW"
    else
        echo -e "$GREEN"
    fi
}

# Function to draw a horizontal bar
# Usage: draw_bar <percentage> <width>
draw_bar() {
    local percent=$1
    local width=$2
    
    # Clamp percentage to 100
    if (( $(echo "$percent > 100" | bc -l) )); then percent=100; fi
    
    local filled=$(printf "%.0f" $(echo "$percent * $width / 100" | bc -l))
    local empty=$((width - filled))
    local color=$(get_color "$percent")
    
    printf "${DIM}[${RESET}"
    printf "%s" "$color"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf "%s" "$RESET"
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "${DIM}]${RESET} %s%5.1f%%%s" "$color" "$percent" "$RESET"
}

# Function to get CPU usage
get_cpu_usage() {
    read cpu a b c idle rest < /proc/stat
    local total=$((a+b+c+idle))
    local idle_prev=$idle
    local total_prev=$total
    
    sleep 1  # 1 second interval
    
    read cpu a b c idle rest < /proc/stat
    total=$((a+b+c+idle))
    local total_diff=$((total - total_prev))
    local idle_diff=$((idle - idle_prev))
    
    if [ "$total_diff" -eq 0 ]; then
        echo "0"
    else
        echo "$((100 * (total_diff - idle_diff) / total_diff))"
    fi
}

# Function to get Memory usage
get_mem_usage() {
    free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}'
}

# Function to get Swap usage
get_swap_usage() {
    free | grep Swap | awk '{if ($2>0) printf "%.1f", $3/$2 * 100; else print "0"}'
}

# Function to get Disk usage (Root)
get_disk_usage() {
    df / | tail -1 | awk '{print $5}' | tr -d '%'
}

# Network Usage Initialization
RX_PREV=0
TX_PREV=0
check_net_init() {
    read RX_PREV TX_PREV <<< $(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev)
}
check_net_init

# Function to get Network usage (KB/s)
get_net_usage() {
    read RX_NOW TX_NOW <<< $(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev)
    
    local rx_diff=$((RX_NOW - RX_PREV))
    local tx_diff=$((TX_NOW - TX_PREV))
    
    RX_PREV=$RX_NOW
    TX_PREV=$TX_NOW
    
    echo "$((rx_diff / 1024)) $((tx_diff / 1024))"
}

# Function to get Load Average
get_load_avg() {
    awk '{print $1, $2, $3}' /proc/loadavg
}

# Function to get Top Processes (Top 5)
get_top_processes() {
    # Comm, CPU, MEM. Sort by CPU desc. Take top 5.
    ps -eo comm:15,%cpu,%mem --sort=-%cpu | head -n 6 | tail -n 5 | awk '{printf "%-15s CPU:%s%% MEM:%s%%", $1, $2, $3}'
}

# Function to get Battery Info
get_battery_info() {
    # Check standard paths
    if [ -d /sys/class/power_supply/BAT0 ]; then
        cat /sys/class/power_supply/BAT0/capacity
    elif [ -d /sys/class/power_supply/BAT1 ]; then
        cat /sys/class/power_supply/BAT1/capacity
    else
        echo "N/A"
    fi
}

# Main Loop
while true; do
    # Header
    tput cup 0 0
    echo -e "${BOLD}${WHITE}${BLUE} AKASHIC RECORDS DASHBOARD ${RESET}"
    echo -e "${CYAN}Hostname:${RESET} $(hostname) ${DIM}|${RESET} ${CYAN}OS:${RESET} $(uname -o) ${DIM}|${RESET} ${CYAN}Kernel:${RESET} $(uname -r)"
    echo -e "${CYAN}Uptime:${RESET}   $(uptime -p)"
    echo -e "${CYAN}Clock:${RESET}    $(date +'%H:%M:%S') ${DIM}|${RESET} ${CYAN}Load Avg:${RESET} $(get_load_avg)"
    echo -e "${DIM}------------------------------------------------------------${RESET}"

    # CPU
    cpu_usage=$(get_cpu_usage)
    tput cup 6 0
    printf "%-12s" "${BOLD}CPU:${RESET}"
    draw_bar "$cpu_usage" 40

    # Memory
    mem_usage=$(get_mem_usage)
    tput cup 8 0
    printf "%-12s" "${BOLD}RAM:${RESET}"
    draw_bar "$mem_usage" 40

    # Swap
    swap_usage=$(get_swap_usage)
    tput cup 10 0
    printf "%-12s" "${BOLD}Swap:${RESET}"
    draw_bar "$swap_usage" 40

    # Disk
    disk_usage=$(get_disk_usage)
    tput cup 12 0
    printf "%-12s" "${BOLD}Disk (/):${RESET}"
    draw_bar "$disk_usage" 40

    # Network
    read rx_kb tx_kb <<< $(get_net_usage)
    tput cup 14 0
    printf "%-12s" "${BOLD}Network:${RESET}"
    echo -en "RX: ${GREEN}${rx_kb} KB/s${RESET} ${DIM}|${RESET} TX: ${RED}${tx_kb} KB/s${RESET}      "

    # Battery
    bat_cap=$(get_battery_info)
    tput cup 16 0
    printf "%-12s" "${BOLD}Battery:${RESET}"
    if [ "$bat_cap" == "N/A" ]; then
        echo -en "${DIM}N/A${RESET}"
    else
        # Color coding for battery
        if [ "$bat_cap" -gt 60 ]; then
             echo -en "${GREEN}${bat_cap}%${RESET}"
        elif [ "$bat_cap" -gt 20 ]; then
             echo -en "${YELLOW}${bat_cap}%${RESET}"
        else
             echo -en "${RED}${BOLD}${bat_cap}%${RESET}"
        fi
    fi

    # Top Processes
    tput cup 18 0
    echo -e "${BOLD}Top Processes (CPU/MEM):${RESET}"
    tput cup 19 0
    get_top_processes | while read line; do
        echo -e "  ${MAGENTA}${line}${RESET}"
    done

    # Footer
    tput cup 25 0
    echo -e "${DIM}------------------------------------------------------------${RESET}"
    echo -e "Press ${BOLD}${RED}q${RESET} to quit."

    # Input handling
    local key
    if [[ -n "$ZSH_VERSION" ]]; then
        read -t 0.1 -k 1 key || true
    else
        read -t 0.1 -n 1 key || true
    fi
    if [[ $key == "q" ]]; then
        cleanup
    fi
done
