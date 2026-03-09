#!/bin/bash
# src/ui.sh
# UI Rendering and Dashboard logic

# Ensure dependencies
if [[ -z "${NC:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/core.sh" ]]; then source "$SCRIPT_DIR/core.sh"; fi
fi

# We expect sysinfo functions to be available. 
# If not, we should probably source them or rely on main.sh.
# For safety in standalone testing:
if ! command -v get_cpu_usage &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/sysinfo.sh" ]]; then source "$SCRIPT_DIR/sysinfo.sh"; fi
fi

# ==========================================
# 1. Common UI Components
# ==========================================

print_header() {
    clear
    echo -e "${BLUE}${BOLD}=================================================${NC}"
    echo -e "${BLUE}${BOLD}        AKASHIC RECORDS (System Utility)         ${NC}"
    echo -e "${BLUE}${BOLD}=================================================${NC}"
    echo ""
}

pause() {
    echo ""
    echo -en "Press [Enter] key to continue..."
    read -r
    echo ""
}

# Get color based on percentage (High = Red)
get_color() {
    local percent=$1
    # Use bc if available, else integer comparison
    if command -v bc &>/dev/null; then
         if (( $(echo "$percent >= 80" | bc -l) )); then echo "$RED";
         elif (( $(echo "$percent >= 50" | bc -l) )); then echo "$YELLOW";
         else echo "$GREEN"; fi
    else
         # Integer fallback
         local p_int=${percent%.*}
         if (( p_int >= 80 )); then echo "$RED";
         elif (( p_int >= 50 )); then echo "$YELLOW";
         else echo "$GREEN"; fi
    fi
}

# Draw horizontal bar
# Usage: draw_bar <percent> <width>
draw_bar() {
    local percent=$1
    local width=$2
    
    # Clamp to 100
    local p_val=${percent%.*} # integer for loop
    if (( p_val > 100 )); then p_val=100; percent=100; fi
    
    # Calculate filled width
    local filled
    if command -v bc &>/dev/null; then
        filled=$(printf "%.0f" $(echo "$percent * $width / 100" | bc -l))
    else
        filled=$((p_val * width / 100))
    fi
    
    local empty=$((width - filled))
    local color
    color=$(get_color "$percent")
    
    printf "${DIM}[${RESET}"
    printf "%s" "$color"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf "%s" "$RESET"
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "${DIM}]${RESET} %s%5.1f%%%s" "$color" "$percent" "$RESET"
}

# ==========================================
# 2. Detailed Info Renderers (Text Mode)
# ==========================================

render_system_overview() {
    echo -e "${GREEN}${BOLD}--- System Overview ---${NC}"
    echo -e "${BOLD}Hostname:${NC} $(hostname)"
    echo -e "${BOLD}Uptime:${NC} $(uptime -p)"
    echo -e "${BOLD}Current Time:${NC} $(date)"
    echo ""
    echo -e "${BOLD}OS Information:${NC}"
    if [ -f /etc/os-release ]; then
        # Use grep/sed to extract pretty lines
        grep -E '^(NAME|VERSION|ID|PRETTY_NAME)=' /etc/os-release | sed 's/^/  /'
    else
        echo "  /etc/os-release not found."
    fi
    echo ""
    echo -e "${BOLD}Kernel Version:${NC} $(uname -sr)"
    echo -e "${BOLD}Architecture:${NC} $(uname -m)"
    echo ""
    echo -e "${BOLD}Logged in Users:${NC}"
    who
}

render_cpu_info() {
    echo -e "${GREEN}${BOLD}--- CPU Information ---${NC}"
    if check_cmd lscpu; then
        lscpu | grep -E 'Architecture|CPU\(s\):|Model name|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|MHz'
    else
        grep -m 1 'model name' /proc/cpuinfo
        grep -m 1 'cpu cores' /proc/cpuinfo
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}--- Memory Information ---${NC}"
    free -h
    echo ""
    echo -e "${BOLD}Top 5 Memory Consuming Processes:${NC}"
    # Calls sysinfo helper or runs ps directly (helper returned string, sticking to raw ps for detailed table)
    # Actually sysinfo helper returns truncated string. Let's run full ps here for detail view.
    ps -eo user:12,pid:8,%cpu:6,%mem:6,start:10,comm:25 --sort=-%mem | head -n 6 || true
    
    echo ""
    echo -e "${CYAN}${BOLD}Legend:${NC}"
    echo -e "  ${BOLD}USER${NC}: Process Owner   ${BOLD}PID${NC}: Process ID"
    echo -e "  ${BOLD}%CPU${NC}: CPU Usage %     ${BOLD}%MEM${NC}: RAM Usage %"
    echo -e "  ${BOLD}START${NC}: Start Time     ${BOLD}COMMAND${NC}: Process Name"
}

render_storage_info() {
    echo -e "${GREEN}${BOLD}--- Block Devices ---${NC}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL || echo "lsblk failed"
    echo ""
    echo -e "${GREEN}${BOLD}--- Disk Usage ---${NC}"
    df -hT --exclude-type=tmpfs --exclude-type=devtmpfs
    echo ""
    echo -e "${GREEN}${BOLD}--- Mounted Filesystems ---${NC}"
    mount | column -t | head -n 10 || true
    echo "... (truncated)"
}

render_hardware_info() {
    echo -e "${GREEN}${BOLD}--- PCI Devices ---${NC}"
    if check_cmd lspci; then lspci; else echo "lspci not found."; fi
    echo ""
    echo -e "${GREEN}${BOLD}--- USB Devices ---${NC}"
    if check_cmd lsusb; then lsusb; else echo "lsusb not found."; fi
    echo ""
    echo -e "${GREEN}${BOLD}--- Input Devices ---${NC}"
    if [[ -f /proc/bus/input/devices ]]; then
        grep -E 'Name|Handlers' /proc/bus/input/devices | paste - -
    fi
}

render_network_info() {
    echo -e "${GREEN}${BOLD}--- IP Addresses ---${NC}"
    ip -c addr show
    echo ""
    echo -e "${GREEN}${BOLD}--- Routing Table ---${NC}"
    ip -c route show
    echo ""
    echo -e "${GREEN}${BOLD}--- DNS Configuration ---${NC}"
    if [[ -f /etc/resolv.conf ]]; then
        cat /etc/resolv.conf | grep -v '^#'
    fi
    echo ""
    echo -e "${GREEN}${BOLD}--- Listening Ports (TCP) ---${NC}"
    if check_cmd ss; then ss -tulpn | head -n 10 || true; else echo "ss not found"; fi
    echo ""
    echo -e "${GREEN}${BOLD}--- Network Manager Status ---${NC}"
    if check_cmd nmcli; then nmcli general status; fi
}

render_kernel_info() {
     echo -e "${GREEN}${BOLD}--- Kernel Modules (Loaded) ---${NC}"
     lsmod | head -n 10 || true
     echo "... (total: $(lsmod | wc -l))"
     echo ""
     echo -e "${GREEN}${BOLD}--- Interrupts (Top 10) ---${NC}"
     head -n 10 /proc/interrupts
     echo ""
     echo -e "${GREEN}${BOLD}--- Kernel Boot Parameters ---${NC}"
     cat /proc/cmdline
}

render_container_info() {
    echo -e "${GREEN}${BOLD}--- Docker Containers ---${NC}"
    if check_cmd docker; then
        if docker ps >/dev/null 2>&1; then
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -n 10 || true
        else
            echo "Docker daemon not running or permission denied."
        fi
    else
        echo "Docker not found."
    fi
    echo ""
    echo -e "${GREEN}${BOLD}--- Podman Containers ---${NC}"
    if check_cmd podman; then
        podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -n 10 || true
    else
        echo "Podman not found."
    fi
}

render_service_info() {
    echo -e "${GREEN}${BOLD}--- Failed Systemd Services ---${NC}"
    if check_cmd systemctl; then
        systemctl list-units --state=failed --no-pager
    else
        echo "systemctl not found."
    fi
}

render_pkg_info() {
    echo -e "${GREEN}${BOLD}--- Available Updates ---${NC}"
    echo "Checking for updates (this might take a moment)..."
    
     # Check for Nobara Logic
    if [ -f /etc/os-release ]; then
        # Run in a subshell
        (
            source /etc/os-release
            if [[ "$ID" == "nobara" ]]; then
                echo -e "${YELLOW}Nobara Linux detected. Using 'nobara-sync cli'...${NC}"
                if command -v nobara-sync &> /dev/null; then
                     nobara-sync cli
                     exit 0
                else
                     echo -e "${RED}Error: 'nobara-sync' command not found.${NC}"
                     exit 1
                fi
            fi
            exit 2 # Not Nobara
        )
        ret=$?
        if [ $ret -eq 0 ]; then return; fi
        if [ $ret -eq 1 ]; then return; fi
    fi

    if check_cmd dnf; then
        dnf check-update --quiet | head -n 10 || true
    elif check_cmd apt; then
        apt list --upgradable 2>/dev/null | head -n 10 || true
    elif check_cmd pacman; then
        if check_cmd checkupdates; then
             checkupdates | head -n 10 || true
        else
             echo "checkupdates command not found (install pacman-contrib)."
        fi
    else
        echo "No supported package manager found for update check."
    fi
}

render_glossary() {
    echo -e "${GREEN}${BOLD}--- Tech Glossary & Cheat Sheet ---${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}1. Storage & Memory${NC}"
    echo -e "   - ${BOLD}GB vs GiB${NC}: GB=1000^3 (Marketing), GiB=1024^3 (Real Size). 500GB = 465GiB."
    echo -e "   - ${BOLD}RAM${NC}: Fast, temporary workspace. Wiped on restart."
    echo -e "   - ${BOLD}Swap${NC}: Emergency RAM on your hard drive. Slow, prevents crashes."
    echo -e "   - ${BOLD}Filesystem${NC}: How data is organized (e.g., ext4, ntfs)."
    echo ""
    echo -e "${CYAN}${BOLD}2. CPU & Architecture${NC}"
    echo -e "   - ${BOLD}x64 / amd64${NC}: Modern 64-bit chips. Standard for desktops/laptops."
    echo -e "   - ${BOLD}ARM / aarch64${NC}: Power-efficient chips (Phones, Macs, Raspberry Pi)."
    echo -e "   - ${BOLD}Load Avg${NC}: CPU busyness. 1.0 = 1 core 100% busy."
    echo ""
    echo -e "${CYAN}${BOLD}3. Network Lingo${NC}"
    echo -e "   - ${BOLD}IP Address${NC}: Your computer's ID card on the network."
    echo -e "   - ${BOLD}DNS${NC}: Internet phonebook (google.com -> 142.250...)."
    echo -e "   - ${BOLD}TCP vs UDP${NC}: TCP = Receipt required (Web). UDP = Throw it (Gaming)."
    echo ""
    echo -e "${CYAN}${BOLD}4. System Jargon${NC}"
    echo -e "   - ${BOLD}PID${NC}: Process ID. Unique number for every running program."
    echo -e "   - ${BOLD}Kernel${NC}: The core of the OS. Controls hardware."
    echo -e "   - ${BOLD}Daemon${NC}: A background service (invisible worker)."
    echo -e "   - ${BOLD}Root${NC}: The Superuser/Administrator (God mode)."
    echo -e "   - ${BOLD}Distro${NC}: Flavor of Linux (Ubuntu, Fedora, Arch, etc.)."
    echo ""
}

# ==========================================
# 3. Interactive TUI Dashboard
# ==========================================

start_dashboard() {
    # Initialize network stats
    sysinfo_net_init
    
    tput civis # Hide cursor
    clear

    # Inner cleanup for dashboard
    dashboard_cleanup() {
        tput cnorm
        tput sgr0
        clear
        # Do NOT exit, just return to menu if possible, but trap usually exits.
        # If this function is "trapped", we might need to handle it.
        # But for now, user presses 'q' to break loop.
    }

    # Use a loop that checks for input
    while true; do
        # Header
        tput cup 0 0
        echo -e "${BOLD}${WHITE}${BLUE} AKASHIC RECORDS DASHBOARD ${RESET}"
        echo -e "${CYAN}Hostname:${RESET} $(hostname) ${DIM}|${RESET} ${CYAN}OS:${RESET} ${SYS_DISTRO:-Linux} ${DIM}|${RESET} ${CYAN}Kernel:${RESET} $(uname -r)"
        echo -e "${CYAN}Uptime:${RESET}   $(uptime -p)"
        echo -e "${CYAN}Clock:${RESET}    $(date +'%H:%M:%S') ${DIM}|${RESET} ${CYAN}Load Avg:${RESET} $(get_load_avg)"
        echo -e "${DIM}------------------------------------------------------------${RESET}"
    
        # CPU
        local cpu_usage
        cpu_usage=$(get_cpu_usage) # This sleeps for 0.1s
        tput cup 6 0
        printf "%-12s" "${BOLD}CPU:${RESET}"
        draw_bar "$cpu_usage" 40
    
        # Memory
        local mem_usage
        mem_usage=$(get_mem_usage)
        tput cup 8 0
        printf "%-12s" "${BOLD}RAM:${RESET}"
        draw_bar "$mem_usage" 40
    
        # Swap
        local swap_usage
        swap_usage=$(get_swap_usage)
        tput cup 10 0
        printf "%-12s" "${BOLD}Swap:${RESET}"
        draw_bar "$swap_usage" 40
    
        # Disk
        local disk_usage
        disk_usage=$(get_disk_usage "/")
        tput cup 12 0
        printf "%-12s" "${BOLD}Disk (/):${RESET}"
        draw_bar "$disk_usage" 40
    
        # Network
        local rx_kb tx_kb
        read -r rx_kb tx_kb <<< "$(get_net_usage)"
        tput cup 14 0
        printf "%-12s" "${BOLD}Network:${RESET}"
        echo -en "RX: ${GREEN}${rx_kb} KB/s${RESET} ${DIM}|${RESET} TX: ${RED}${tx_kb} KB/s${RESET}      "
    
        # Battery
        local bat_cap
        bat_cap=$(get_battery_info)
        tput cup 16 0
        printf "%-12s" "${BOLD}Battery:${RESET}"
        if [ "$bat_cap" == "N/A" ]; then
            echo -en "${DIM}N/A${RESET}"
        else
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
        # get_top_processes returns multiple lines.
        # We need to print them carefully.
        local row=19
        get_top_processes | while read -r line; do
             tput cup $row 2
             echo -e "${MAGENTA}${line}${RESET}"
             ((row++))
        done
    
        # Footer
        tput cup 25 0
        echo -e "${DIM}------------------------------------------------------------${RESET}"
        echo -e "Press ${BOLD}${RED}q${RESET} to quit."
    
        # Input handling (Non-blocking read with timeout 0.1s)
        # Since get_cpu_usage already slept 0.1s, we can just do a very short check.
        local key
        if [[ -n "$ZSH_VERSION" ]]; then
            read -t 0.1 -k 1 key || true
        else
            read -t 0.1 -n 1 key || true
        fi
        
        if [[ "${key:-}" == "q" ]]; then
            dashboard_cleanup
            break
        fi
    done
}

# ==========================================
# 4. Interactive Menus
# ==========================================

# Generic Interactive Menu
# Arguments: title, options_array_name
# Returns: selected index in global variable 'MENU_SELECTED_INDEX'
interactive_menu() {
    local title="$1"
    local reference_name="$2"
    
    # Bash 3.2+ compatibility using eval instead of local -n
    local length
    eval "length=\${#${reference_name}[@]}"
    local selected=0
    
    # Internal loop for this specific menu
    while true; do
        clear
        echo -e "${BLUE}${BOLD}=================================================${NC}"
        echo -e "${BLUE}${BOLD}        AKASHIC RECORDS (System Utility)         ${NC}"
        echo -e "${BLUE}${BOLD}=================================================${NC}"
        echo ""
        echo -e "${YELLOW}${BOLD}:: $title ::${NC}"
        echo -e "Use ${BOLD}Up/Down${NC} to navigate, ${BOLD}Enter${NC} to select."
        echo ""

        local start_idx=0
        if [[ -n "$ZSH_VERSION" ]]; then
            start_idx=1
        fi

        for ((i=0; i<length; i++)); do
            local array_idx=$((i + start_idx))
            local item
            eval "item=\"\${${reference_name}[$array_idx]}\""
            if [[ "$i" == "$selected" ]]; then
                echo -e "${GREEN}${BOLD}> ${item} <${NC}"
            else
                echo -e "  ${item}"
            fi
        done
        echo ""

        # Input handling
        local input
        if [[ -n "$ZSH_VERSION" ]]; then
            read -rs -k 1 input
        else
            read -rsn1 input
        fi
        
        if [[ "$input" == $'\x1b' ]]; then
            if [[ -n "$ZSH_VERSION" ]]; then
                read -rs -k 2 input
            else
                read -rsn2 input
            fi
            if [[ "$input" == "[A" ]]; then # Up
                ((selected--))
                if ((selected < 0)); then selected=$((length - 1)); fi
            elif [[ "$input" == "[B" ]]; then # Down
                ((selected++))
                if ((selected >= length)); then selected=0; fi
            fi
        elif [[ "$input" == "" ]]; then # Enter
            MENU_SELECTED_INDEX=$selected
            return 0
        fi
    done
}

