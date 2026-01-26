#!/bin/bash
# src/main.sh
# Main entry point and orchestration.

# Resolve directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Modules
# shellcheck source=src/core.sh
source "$SCRIPT_DIR/core.sh"
# shellcheck source=src/sysinfo.sh
source "$SCRIPT_DIR/sysinfo.sh"
# shellcheck source=src/ui.sh
source "$SCRIPT_DIR/ui.sh"
# shellcheck source=src/installer.sh
source "$SCRIPT_DIR/installer.sh"

# Set up Cleanup Trap
trap cleanup EXIT INT TERM

# Argument Parsing
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
            --dashboard)
                start_dashboard
                exit 0
                ;;
            --install)
                install_zsh_environment
                exit 0
                ;;
            --report)
                generate_report
                exit 0
                ;;
            --json)
                generate_json
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --dashboard   Launch the TUI dashboard directly"
                echo "  --install     Run the Zsh environment installer"
                echo "  --report      Generate a system text report"
                echo "  --json        Generate a system JSON export"
                echo "  --dry-run     Simulate actions (for installer)"
                echo "  --verbose     Enable debug logging"
                exit 0
                ;;
        esac
    done
}

# --- Reporting Functions ---

generate_report() {
    local REPORT_FILE="system_report_$(date +%Y%m%d_%H%M%S).txt"
    echo "Generating full report to $REPORT_FILE..."
    
    {
        echo "========================================="
        echo "      FULL SYSTEM INFORMATION REPORT     "
        echo "========================================="
        echo "Generated on: $(date)"
        echo ""
        
        echo "=== SYSTEM OVERVIEW ==="
        render_system_overview
        echo ""
        
        echo "=== CPU & MEMORY ==="
        render_cpu_info
        echo ""
        
        echo "=== STORAGE ==="
        render_storage_info
        echo ""
        
        echo "=== HARDWARE ==="
        render_hardware_info
        echo ""
        
        echo "=== NETWORK ==="
        render_network_info
        echo ""
        
        echo "=== KERNEL ==="
        render_kernel_info
        echo ""

        echo "=== CONTAINERS ==="
        render_container_info
        echo ""

        echo "=== FAILED SERVICES ==="
        render_service_info
        echo ""
         # Package info can take time and might require interactive sudo in some cases (though usually check is safe)
         # We skip it for static report or keep it simple?
         # render_pkg_info prints to stdout and has progress text.
         # For a report file, maybe omit or keep simple.
         # akashic included it (package_info).
         # We'll include it.
        echo "=== UPDATES ==="
        render_pkg_info
        echo ""
        
    } > "$REPORT_FILE" 2>&1
    
    # Remove color codes
    if command -v sed &>/dev/null; then
        sed -i 's/\x1b\[[0-9;]*m//g' "$REPORT_FILE" || true
    fi
    
    echo -e "${GREEN}Report saved successfully to $REPORT_FILE${NC}"
    if [[ -t 0 ]]; then
        pause
    fi
}

generate_json() {
    local JSON_FILE="system_info_$(date +%Y%m%d_%H%M%S).json"
    echo "Exporting system info to $JSON_FILE..."
    
    # We can use sysinfo getters
    local hostname=$(hostname)
    local uptime=$(uptime -p)
    local kernel=$(uname -sr)
    local arch=$(uname -m)
    # Be careful with multiline output hacks in JSON manually
    local memory_total=$(get_mem_usage) # Returns %, not total string. 
    # Original akashic did: free -h | grep Mem | awk '{print $2}'
    local mem_total_str=$(free -h | grep Mem | awk '{print $2}')
    local disk_usage=$(get_disk_usage "/") 
    
    cat <<EOF > "$JSON_FILE"
{
  "hostname": "$hostname",
  "uptime": "$uptime",
  "date": "$(date)",
  "kernel": "$kernel",
  "architecture": "$arch",
  "memory_total": "$mem_total_str",
  "disk_usage_root_percent": "$disk_usage"
}
EOF
    echo -e "${GREEN}JSON export saved to $JSON_FILE${NC}"
    if [[ -t 0 ]]; then
        pause
    fi
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
            0) clear; render_system_overview; pause ;;
            1) clear; render_cpu_info; pause ;;
            2) clear; render_storage_info; pause ;;
            3) clear; render_hardware_info; pause ;;
            4) clear; render_kernel_info; pause ;;
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
            0) clear; render_network_info; pause ;;
            1) clear; render_container_info; pause ;;
            2) clear; render_service_info; pause ;;
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
            0) clear; render_pkg_info; pause ;;
            1) clear; install_zsh_environment ;;
            2) start_dashboard ;;
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
            2) clear; render_glossary; pause ;;
            3) return ;;
        esac
    done
}

# --- Main Entry Point ---

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    
    # If no args, show main menu
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
