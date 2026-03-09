#!/bin/bash
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color
# Header function
print_header() {
    clear
    echo -e "${BLUE}${BOLD}=================================================${NC}"
    echo -e "${BLUE}${BOLD}        AKASHIC RECORDS (System Utility)         ${NC}"
    echo -e "${BLUE}${BOLD}=================================================${NC}"
    echo ""
}
# Pause function
pause() {
    echo ""
    echo -en "Press [Enter] key to continue..."
    read -r
}

# Global Flags
IS_DRY_RUN=0
IS_VERBOSE=0

# Logging Helpers
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_verbose() {
    if [[ "$IS_VERBOSE" -eq 1 ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Argument Parsing (Manual implementation for simple flags)
parse_args() {
    for arg in "$@"; do
        case $arg in
            --dry-run)
                IS_DRY_RUN=1
                log_info "Dry-run mode enabled. No changes will be made."
                ;;
            --verbose)
                IS_VERBOSE=1
                log_info "Verbose logging enabled."
                ;;
        esac
    done
}

# Function to check command availability
check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        log_verbose "Command '$1' not found."
        return 1
    fi
    return 0
}

# Check sudo and auto-re-exec
# Usage: check_sudo "Operation Description"
check_sudo() {
    local reason="$1"
    
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    
    log_warn "This operation requires root privileges."
    if [[ -n "$reason" ]]; then
        echo -e "Reason: ${BOLD}$reason${NC}"
    fi

    echo -e "${YELLOW}The script will attempt to re-execute itself with sudo.${NC}"
    echo -en "Do you want to proceed? (Y/n): "
    read -r confirm
    if [[ -n "$confirm" && ! "$confirm" =~ ^[Yy]$ ]]; then
        log_error "Operation aborted by user."
        return 1
    fi
    
    log_info "Re-executing with sudo..."
    
    # Preserve arguments
    sudo -E "$0" "$@"
    exit $?
}

# Advanced System Detection & Capability Matrix
# Exports: SYS_DISTRO, SYS_PM, SYS_HAS_AUR
declare -A CAPABILITY_MATRIX

detect_capabilities() {
    log_info "Detecting system capabilities..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        SYS_DISTRO="$ID"
    else
        log_error "Cannot detect OS (no /etc/os-release)."
        return 1
    fi

    log_verbose "Detected OS ID: $SYS_DISTRO"

    # Identify Package Manager & Family
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

    log_info "Detected Package Manager: $SYS_PM"
    if [[ -n "$SYS_AUR" ]]; then
        log_info "Detected AUR Helper: $SYS_AUR"
    fi

    # Build Capability Matrix
    # Format: "plugin:method" -> "source"
    
    # ZSH
    CAPABILITY_MATRIX["zsh"]="$SYS_PM"
    
    # Starship (Script is universal fallback, but some PMs have it)
    if [[ "$SYS_PM" == "pacman" ]]; then
        CAPABILITY_MATRIX["starship"]="pacman"
    else
        CAPABILITY_MATRIX["starship"]="script"
    fi

    # Autosuggestions
    case "$SYS_PM" in
        apt) CAPABILITY_MATRIX["zsh-autosuggestions"]="apt" ;; # zsh-autosuggestions
        pacman) CAPABILITY_MATRIX["zsh-autosuggestions"]="pacman" ;; # zsh-autosuggestions
        dnf) CAPABILITY_MATRIX["zsh-autosuggestions"]="dnf" ;; # zsh-autosuggestions
        *) CAPABILITY_MATRIX["zsh-autosuggestions"]="git" ;;
    esac

    # Syntax Highlighting
    case "$SYS_PM" in
        apt) CAPABILITY_MATRIX["zsh-syntax-highlighting"]="apt" ;; # zsh-syntax-highlighting
        pacman) CAPABILITY_MATRIX["zsh-syntax-highlighting"]="pacman" ;; # zsh-syntax-highlighting
        dnf) CAPABILITY_MATRIX["zsh-syntax-highlighting"]="dnf" ;; # zsh-syntax-highlighting
        *) CAPABILITY_MATRIX["zsh-syntax-highlighting"]="git" ;;
    esac

    # Autocomplete (Usually Git)
    CAPABILITY_MATRIX["zsh-autocomplete"]="git"
}

# --- Installation Helpers ---

# Check if a component is installed
# Usage: is_installed "command_name" "/optional/path/to/dir"
is_installed() {
    local cmd="$1"
    local dir="$2"
    
    if [[ -n "$cmd" ]] && command -v "$cmd" &> /dev/null; then
        return 0
    fi
    
    if [[ -n "$dir" ]] && [[ -d "$dir" ]]; then
        return 0
    fi
    
    return 1
}

# Backup Configuration
backup_config() {
    local backup_root="$HOME/.zsh_backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$backup_root/$timestamp"
    
    log_info "Creating backup at $backup_dir..."
    
    if [[ "$IS_DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Would create directory $backup_dir"
        log_info "[DRY-RUN] Would copy ~/.zshrc to backup"
        log_info "[DRY-RUN] Would copy ~/.zshplugins to backup"
        return 0
    fi
    
    mkdir -p "$backup_dir"
    
    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$backup_dir/"
    fi
    
    if [[ -d "$HOME/.zshplugins" ]]; then
        cp -r "$HOME/.zshplugins" "$backup_dir/"
    fi
}

# Block-based .zshrc generation
# Usage: generate_zshrc_blocks "source_file" "target_file" "array_of_excluded_plugins"
generate_zshrc_blocks() {
    local source_file="$1"
    local target_file="$2"
    shift 2
    local -a excluded_plugins=("$@")
    
    log_info "Generating .zshrc configuration..."
    
    if [[ "$IS_DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Using source template: $source_file"
        log_info "[DRY-RUN] Filtered plugins: ${excluded_plugins[*]}"
        log_info "[DRY-RUN] Writing to: $target_file"
        return 0
    fi

    # Read file line by line to handle blocks
    local in_block=0
    local current_plugin=""
    
    # Empty target file first
    > "$target_file"
    
    # Regex patterns
    local start_block_regex="^# >>> plugin:([a-zA-Z0-9_-]+) >>>$"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for block start
        if [[ "$line" =~ $start_block_regex ]]; then
            current_plugin="${BASH_REMATCH[1]}"
            in_block=1
            
            # Check if this plugin is excluded
            local skip_block=0
            for excluded in "${excluded_plugins[@]}"; do
                if [[ "$excluded" == "$current_plugin" ]]; then
                    skip_block=1
                    break
                fi
            done
            
            if [[ "$skip_block" -eq 1 ]]; then
                # Skip this block (don't write start marker)
                # But we need to consume lines until end marker
                local end_block_regex="^# <<< plugin:$current_plugin <<<$"
                while IFS= read -r inner_line || [[ -n "$inner_line" ]]; do
                     if [[ "$inner_line" =~ $end_block_regex ]]; then
                         break
                     fi
                done
                in_block=0
                current_plugin=""
                continue
            fi
        fi
        
        # Write line
        echo "$line" >> "$target_file"
        
        # Check for block end
        local end_marker_regex="^# <<< plugin:.*$"
        if [[ "$line" =~ $end_marker_regex ]]; then
            in_block=0
            current_plugin=""
        fi
    done < "$source_file"
    
    log_info "Configuration written to $target_file"
}


# 1. System Overview
system_overview() {
    echo -e "${GREEN}${BOLD}--- System Overview ---${NC}"
    echo -e "${BOLD}Hostname:${NC} $(hostname)"
    echo -e "${BOLD}Uptime:${NC} $(uptime -p)"
    echo -e "${BOLD}Current Time:${NC} $(date)"
    echo ""
    echo -e "${BOLD}OS Information:${NC}"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release | grep -E '^(NAME|VERSION|ID|PRETTY_NAME)=' | sed 's/^/  /'
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
# 2. CPU & Memory
cpu_memory_info() {
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
    # Formatted ps output: User, PID, CPU%, Mem%, Start Time, Command (truncated)
    ps -eo user:12,pid:8,%cpu:6,%mem:6,start:10,comm:25 --sort=-%mem | head -n 6
    
    echo ""
    echo -e "${CYAN}${BOLD}Legend:${NC}"
    echo -e "  ${BOLD}USER${NC}: Process Owner   ${BOLD}PID${NC}: Process ID"
    echo -e "  ${BOLD}%CPU${NC}: CPU Usage %     ${BOLD}%MEM${NC}: RAM Usage %"
    echo -e "  ${BOLD}START${NC}: Start Time     ${BOLD}COMMAND${NC}: Process Name"
}
# 3. Storage & Filesystems
storage_info() {
    echo -e "${GREEN}${BOLD}--- Block Devices ---${NC}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
    echo ""
    echo -e "${GREEN}${BOLD}--- Disk Usage ---${NC}"
    df -hT --exclude-type=tmpfs --exclude-type=devtmpfs
    echo ""
    echo -e "${GREEN}${BOLD}--- Mounted Filesystems ---${NC}"
    mount | column -t | head -n 10
    echo "... (truncated)"
}
# 4. Hardware Devices
hardware_info() {
    echo -e "${GREEN}${BOLD}--- PCI Devices ---${NC}"
    if check_cmd lspci; then
        lspci
    else
        echo "lspci not found."
    fi
    echo ""
    echo -e "${GREEN}${BOLD}--- USB Devices ---${NC}"
    if check_cmd lsusb; then
        lsusb
    else
        echo "lsusb not found."
    fi
    echo ""
    echo -e "${GREEN}${BOLD}--- Input Devices ---${NC}"
    grep -E 'Name|Handlers' /proc/bus/input/devices | paste - -
}
# 5. Network Information
network_info() {
    echo -e "${GREEN}${BOLD}--- IP Addresses ---${NC}"
    ip -c addr show
    echo ""
    echo -e "${GREEN}${BOLD}--- Routing Table ---${NC}"
    ip -c route show
    echo ""
    echo -e "${GREEN}${BOLD}--- DNS Configuration ---${NC}"
    cat /etc/resolv.conf | grep -v '^#'
    echo ""
    echo -e "${GREEN}${BOLD}--- Listening Ports (TCP) ---${NC}"
    ss -tulpn | head -n 10
    echo ""
    echo -e "${GREEN}${BOLD}--- Network Manager Status ---${NC}"
    if check_cmd nmcli; then
        nmcli general status
    fi
}
# 6. Low-Level / Kernel
kernel_info() {
    echo -e "${GREEN}${BOLD}--- Kernel Modules (Loaded) ---${NC}"
    lsmod | head -n 10
    echo "... (total: $(lsmod | wc -l))"
    echo ""
    echo -e "${GREEN}${BOLD}--- Interrupts (Top 10) ---${NC}"
    head -n 10 /proc/interrupts
    echo ""
    echo -e "${GREEN}${BOLD}--- Kernel Boot Parameters ---${NC}"
    cat /proc/cmdline
}
# 7. Container Information
container_info() {
    echo -e "${GREEN}${BOLD}--- Docker Containers ---${NC}"
    if check_cmd docker; then
        if docker ps >/dev/null 2>&1; then
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -n 10
        else
            echo "Docker daemon not running or permission denied."
        fi
    else
        echo "Docker not found."
    fi
    echo ""
    echo -e "${GREEN}${BOLD}--- Podman Containers ---${NC}"
    if check_cmd podman; then
        podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -n 10
    else
        echo "Podman not found."
    fi
}

# 8. System Services
service_info() {
    echo -e "${GREEN}${BOLD}--- Failed Systemd Services ---${NC}"
    if check_cmd systemctl; then
        systemctl list-units --state=failed --no-pager
    else
        echo "systemctl not found."
    fi
}

# 9. Package Updates
package_info() {
    echo -e "${GREEN}${BOLD}--- Available Updates ---${NC}"
    echo "Checking for updates (this might take a moment)..."
    
    # Check for Nobara Logic
    if [ -f /etc/os-release ]; then
        # Run in a subshell to avoid polluting checks
        (
            . /etc/os-release
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
        # Check exit code of subshell
        ret=$?
        if [ $ret -eq 0 ]; then return; fi
        if [ $ret -eq 1 ]; then return; fi
        # If 2, continue to standard checks
    fi

    if check_cmd dnf; then
        dnf check-update --quiet | head -n 10
    elif check_cmd apt; then
        apt list --upgradable 2>/dev/null | head -n 10
    elif check_cmd pacman; then
        if check_cmd checkupdates; then
             checkupdates | head -n 10
        else
             echo "checkupdates command not found (install pacman-contrib)."
        fi
    else
        echo "No supported package manager found for update check."
    fi
}

# 10. JSON Export
generate_json() {
    JSON_FILE="system_info_$(date +%Y%m%d_%H%M%S).json"
    echo "Exporting system info to $JSON_FILE..."
    
    # Simple JSON construction
    cat <<EOF > "$JSON_FILE"
{
  "hostname": "$(hostname)",
  "uptime": "$(uptime -p)",
  "date": "$(date)",
  "kernel": "$(uname -sr)",
  "architecture": "$(uname -m)",
  "cpu_model": "$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)",
  "memory_total": "$(free -h | grep Mem | awk '{print $2}')",
  "disk_usage_root": "$(df -h / | tail -1 | awk '{print $5}')"
}
EOF
    echo -e "${GREEN}JSON export saved to $JSON_FILE${NC}"
    pause
}

# 11. Tech Glossary
glossary_info() {
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

# 12. Setup Shell (Detailed & Robust)
install_zsh_environment() {
    # Detect Real User (if running as sudo)
    local real_user="${SUDO_USER:-$USER}"
    local real_home
    if [[ "$real_user" == "root" ]]; then
        # Fallback if we are just root without sudo (unlikely in this context but possible)
        real_home="/root"
    else
        real_home=$(getent passwd "$real_user" | cut -d: -f6)
    fi
    
    echo -e "${GREEN}${BOLD}--- Setup Shell (Zsh + Plugins) ---${NC}"
    log_info "Target User: $real_user ($real_home)"
    
    detect_capabilities || return
    
    # Define Components
    # components: "name|description|commandable_check|path_check"
    local components=(
        "zsh|Zsh Shell|zsh|"
        "starship|Starship Prompt|starship|"
        "zsh-autosuggestions|Autosuggestions||/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh,$real_home/.zshplugins/zsh-autosuggestions"
        "zsh-syntax-highlighting|Syntax Highlighting||/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh,$real_home/.zshplugins/zsh-syntax-highlighting"
        "zsh-autocomplete|Autocomplete||$real_home/.zshplugins/zsh-autocomplete"
    )
    
    local -A selected_components
    local -a excluded_plugins
    local needs_root=0
    
    echo ""
    echo -e "${YELLOW}Select components to install/configure:${NC}"
    
    for item in "${components[@]}"; do
        IFS='|' read -r name desc cmd check_path <<< "$item"
        
        # Check if installed
        local installed_status="Not Installed"
        local is_present=0
        
        # Parse check_path (comma separated)
        local path_found=0
        if [[ -n "$check_path" ]]; then
            IFS=',' read -ra paths <<< "$check_path"
            for p in "${paths[@]}"; do
                if [[ -e "$p" ]]; then path_found=1; break; fi
            done
        fi
        
        if is_installed "$cmd" "" || [[ "$path_found" -eq 1 ]]; then
             installed_status="${GREEN}Installed${NC}"
             is_present=1
        fi
        
        # Prompt
        # Default behavior: If installed, verify config. If not, ask to install.
        if [[ "$is_present" -eq 1 ]]; then
             echo -en "  [${GREEN}x${NC}] $desc is already installed. Enable/Update in .zshrc? (Y/n): "
             read -r choice
        else
             echo -en "  [ ] Install $desc? (Y/n): "
             read -r choice
        fi
        
        if [[ -z "$choice" ]]; then
             choice="y"
        fi
        
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            selected_components[$name]=1
            
            # Check if this requires root
            local method="${CAPABILITY_MATRIX[$name]}"
            if [[ "$method" == "apt" || "$method" == "dnf" || "$method" == "pacman" ]]; then
                needs_root=1
            fi
            
            echo -e "      -> ${GREEN}Selected${NC} (Method: ${method:-git/script})"
        else
            echo -e "      -> ${CYAN}Skipped${NC}"
            # Track excluded plugins for config generation
            if [[ "$name" != "zsh" ]]; then
                excluded_plugins+=("$name")
            fi
        fi
    done

    # --- Sudo Check ---
    if [[ "$needs_root" -eq 1 && "$EUID" -ne 0 ]]; then
        echo ""
        log_warn "Some selected components require package manager access."
        check_sudo "Installing system packages ($(echo "${!selected_components[@]}" | tr ' ' ','))"
    fi

    echo ""
    echo -e "${BLUE}${BOLD}--- Installation Plan ---${NC}"
    # Summary
    for item in "${components[@]}"; do
        IFS='|' read -r name desc _ _ <<< "$item"
        if [[ "${selected_components[$name]}" -eq 1 ]]; then
             echo -e "${BOLD}$desc${NC}: ${GREEN}Install/Configure${NC} [${CAPABILITY_MATRIX[$name]}]"
        else
             echo -e "${BOLD}$desc${NC}: ${CYAN}Skip (exclude from .zshrc)${NC}"
        fi
    done
    
    if [[ "$IS_DRY_RUN" -eq 1 ]]; then
        echo -e "${YELLOW}[DRY-RUN] No changes will be executed.${NC}"
        pause
        return
    fi
    

    
    echo ""
    echo -en "Proceed with changes? (Y/n): "
    read -r confirm
    if [[ -n "$confirm" && ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "Installation cancelled."
        return
    fi
    
    # --- Execution ---
    
    # 1. Backup
    backup_config
    
    # 2. Install each selected component
    for item in "${components[@]}"; do
        IFS='|' read -r name desc cmd check_path <<< "$item"
        if [[ "${selected_components[$name]}" != 1 ]]; then continue; fi
        
        local method="${CAPABILITY_MATRIX[$name]}"
        log_info "Processing $desc..."
        
        case "$method" in
            apt|dnf|pacman)
                # PM Install
                if is_installed "$cmd" "" || [[ -e "${check_path%%,*}" ]]; then
                     log_verbose "$name already installed."
                else
                     case "$method" in
                         apt) sudo apt install -y "$name" ;;
                         dnf) sudo dnf install -y "$name" ;;
                         pacman) sudo pacman -S --noconfirm "$name" ;;
                     esac
                fi
                ;;
            
            script)
                # Script Install (Mainly Starship)
                if [[ "$name" == "starship" ]]; then
                    if command -v starship &> /dev/null; then
                        log_verbose "Starship already installed."
                    else
                        log_info "Installing Starship via script..."
                        curl -sS https://starship.rs/install.sh | sh -s -- -y
                    fi
                fi
                ;;
                
            git)
                # Git Install (Plugins in ~/.zshplugins)
                local plugin_dir="$real_home/.zshplugins/$name"
                local repo_url=""
                
                case "$name" in
                    "zsh-autosuggestions") repo_url="https://github.com/zsh-users/zsh-autosuggestions" ;;
                    "zsh-syntax-highlighting") repo_url="https://github.com/zsh-users/zsh-syntax-highlighting.git" ;;
                    "zsh-autocomplete") repo_url="https://github.com/marlonrichert/zsh-autocomplete.git" ;;
                esac
                
                if [[ -d "$plugin_dir" ]]; then
                    log_verbose "Updating $name via git..."
                    if [[ -w "$plugin_dir" ]]; then
                        git -C "$plugin_dir" pull
                    else
                        # If owned by root (from generic location? No, we are targeting .zshplugins)
                        # Attempt to run as user
                        if command -v sudo &> /dev/null; then
                            sudo -u "$real_user" git -C "$plugin_dir" pull
                        else
                             log_warn "Cannot update $plugin_dir (permission denied)"
                        fi
                    fi
                else
                    log_info "Cloning $name..."
                    mkdir -p "$real_home/.zshplugins"
                    # Ensure directory ownership if created by root
                    if [[ "$EUID" -eq 0 ]]; then
                        chown "$real_user:$(id -gn "$real_user")" "$real_home/.zshplugins"
                    fi
                    
                    if [[ "$EUID" -eq 0 ]]; then
                        sudo -u "$real_user" git clone --depth 1 "$repo_url" "$plugin_dir"
                    else
                        git clone --depth 1 "$repo_url" "$plugin_dir"
                    fi
                fi
                ;;
        esac
    done
    
    # 3. Configure .zshrc
    # Source is current directory .zshrc (project file)
    local template_zshrc="$(dirname "${BASH_SOURCE[0]}")/.zshrc"
    if [[ ! -f "$template_zshrc" ]]; then
        log_error "Template .zshrc not found at $template_zshrc"
        return 1
    fi
    
    generate_zshrc_blocks "$template_zshrc" "$real_home/.zshrc" "${excluded_plugins[@]}"
    
    # Fix ownership of .zshrc if written by root
    if [[ "$EUID" -eq 0 ]]; then
        chown "$real_user:$(id -gn "$real_user")" "$real_home/.zshrc"
    fi

    # 4. Change Default Shell
    local zsh_path=$(command -v zsh)
    if [[ -n "$zsh_path" ]]; then
        # Check current shell of the user
        local current_shell=$(getent passwd "$real_user" | cut -d: -f7)
        
        if [[ "$current_shell" != "$zsh_path" ]]; then
            echo ""
            echo -e "${YELLOW}Current default shell is $current_shell.${NC}"
            read -p "Change default shell to Zsh ($zsh_path)? (Y/n): " change_shell
             if [[ -z "$change_shell" || "$change_shell" =~ ^[Yy]$ ]]; then
                log_info "Changing default shell..."
                if [[ "$IS_DRY_RUN" -eq 1 ]]; then
                    log_info "[DRY-RUN] Would run: chsh -s $zsh_path $real_user"
                else
                    if [[ "$EUID" -eq 0 ]]; then
                        # We are root, easy change
                        if usermod --shell "$zsh_path" "$real_user"; then
                            log_info "Default shell changed successfully."
                        else
                            log_error "Failed to change shell with usermod."
                        fi
                    else
                        # Normal user, use chsh (will prompt password)
                        if chsh -s "$zsh_path"; then
                            log_info "Default shell changed successfully."
                        else
                            log_error "Failed to change shell. You may need to run 'chsh -s $(which zsh)' manually."
                        fi
                    fi
                fi
             fi
        else
            log_verbose "Default shell is already Zsh."
        fi
    fi

    echo ""
    log_info "Installation complete!"
    
    if [[ "$IS_DRY_RUN" -ne 1 ]]; then
        echo -en "Start Zsh now? (Replaces current shell) (Y/n): "
        read -r start_zsh
        if [[ -z "$start_zsh" || "$start_zsh" =~ ^[Yy]$ ]]; then
            log_info "Starting Zsh..."
            # If we are root (sudo), switch to user before exec
            if [[ "$EUID" -eq 0 ]]; then
                 exec sudo -u "$real_user" zsh -l
            else
                 exec zsh -l
            fi
        fi
    fi
 
    pause
}

# Generate Full Report
generate_report() {
    REPORT_FILE="system_report_$(date +%Y%m%d_%H%M%S).txt"
    echo "Generating full report to $REPORT_FILE..."
    
    {
        echo "========================================="
        echo "      FULL SYSTEM INFORMATION REPORT     "
        echo "========================================="
        echo "Generated on: $(date)"
        echo ""
        
        echo "=== SYSTEM OVERVIEW ==="
        system_overview
        echo ""
        
        echo "=== CPU & MEMORY ==="
        cpu_memory_info
        echo ""
        
        echo "=== STORAGE ==="
        storage_info
        echo ""
        
        echo "=== HARDWARE ==="
        hardware_info
        echo ""
        
        echo "=== NETWORK ==="
        network_info
        echo ""
        
        echo "=== KERNEL ==="
        kernel_info
        echo ""

        echo "=== CONTAINERS ==="
        container_info
        echo ""

        echo "=== FAILED SERVICES ==="
        service_info
        echo ""
        
    } > "$REPORT_FILE"
    
    # Remove color codes from the report file for better readability in text editors
    sed -i 's/\x1b\[[0-9;]*m//g' "$REPORT_FILE"
    
    echo -e "${GREEN}Report saved successfully to $REPORT_FILE${NC}"
    pause
}
# Main Menu Loop
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

        for ((i=0; i<length; i++)); do
            local item
            eval "item=\"\${${reference_name}[$i]}\""
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

# --- Submenus ---

submenu_hardware() {
    local options=(
        "System Overview"
        "CPU & Memory Information"
        "Storage & Filesystems"
        "Hardware Devices (PCI/USB)"
        "Low-Level / Kernel Info"
        "Back to Main Menu"
    )
    while true; do
        interactive_menu "Hardware & Core Info" options
        case $MENU_SELECTED_INDEX in
            0) clear; system_overview; pause ;;
            1) clear; cpu_memory_info; pause ;;
            2) clear; storage_info; pause ;;
            3) clear; hardware_info; pause ;;
            4) clear; kernel_info; pause ;;
            5) return ;;
        esac
    done
}

submenu_network() {
    local options=(
        "Network Information"
        "Container Information"
        "Failed System Services"
        "Back to Main Menu"
    )
    while true; do
        interactive_menu "Network & Services" options
        case $MENU_SELECTED_INDEX in
            0) clear; network_info; pause ;;
            1) clear; container_info; pause ;;
            2) clear; service_info; pause ;;
            3) return ;;
        esac
    done
}

submenu_tools() {
    local options=(
        "Check Package Updates"
        "Setup Shell (Interactive Zsh Installer)"
        "Launch Live Dashboard (TUI)"
        "Back to Main Menu"
    )
    while true; do
        interactive_menu "Tools & Maintenance" options
        case $MENU_SELECTED_INDEX in
            0) clear; package_info; pause ;;
            1) clear; install_zsh_environment ;;
            2) ./dashboard.sh ;;
            3) return ;;
        esac
    done
}

submenu_reports() {
    local options=(
        "Generate Full Report (Save to file)"
        "Export to JSON"
        "Tech Glossary (What do these terms mean?)"
        "Back to Main Menu"
    )
    while true; do
        interactive_menu "Reports & Help" options
        case $MENU_SELECTED_INDEX in
            0) generate_report ;;
            1) generate_json ;;
            2) clear; glossary_info; pause ;;
            3) return ;;
        esac
    done
}

# Main Menu Loop
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main_options=(
        "Hardware & Core Info"
        "Network & Services"
        "Tools & Maintenance"
        "Reports & Help"
        "Exit"
    )

    while true; do
        interactive_menu "Main Menu" main_options
        case $MENU_SELECTED_INDEX in
            0) submenu_hardware ;;
            1) submenu_network ;;
            2) submenu_tools ;;
            3) submenu_reports ;;
            4) echo "Exiting..."; exit 0 ;;
        esac
    done
fi