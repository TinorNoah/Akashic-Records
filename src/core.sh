#!/bin/bash
# src/core.sh
# Core utilities, colors, and safety settings.

# Strict shell safety
set -euo pipefail
IFS=$'\n\t'

# --- Colors & Styling ---
# Try to use tput if available, fallback to ANSI
if command -v tput &>/dev/null && tput setaf 1 &>/dev/null; then
    BLACK=$(tput setaf 0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    
    BOLD=$(tput bold)
    DIM=$(tput dim)
    REVERSE=$(tput rev)
    NC=$(tput sgr0) # No Color / Reset
    RESET=$(tput sgr0)
else
    # ANSI Fallbacks
    BLACK='\033[0;30m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    
    BOLD='\033[1m'
    DIM='\033[2m'
    REVERSE='\033[7m'
    NC='\033[0m'
    RESET='\033[0m'
fi

# Configuration Globals
IS_DRY_RUN=0
IS_VERBOSE=0

# --- Cleanup & Traps ---
cleanup() {
    # Restore cursor if needed (tput cnorm)
    if command -v tput &>/dev/null; then
        tput cnorm || true
        tput sgr0 || true
    fi
    # Additional cleanup can go here
}
# Trap allows modules to define cleanup, but we provide a base.
# Users of this module should call `trap cleanup EXIT INT TERM` if they are the main script.

# --- Logging ---
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_verbose() {
    if [[ "$IS_VERBOSE" -eq 1 ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# --- Utilities ---

# Check if a command exists
check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        log_verbose "Command '$1' not found."
        return 1
    fi
    return 0
}

# Check if a command or directory exists (Installation Helper)
is_installed() {
    local cmd="$1"
    local dir="${2:-}"
    
    if [[ -n "$cmd" ]] && command -v "$cmd" &> /dev/null; then
        return 0
    fi
    
    if [[ -n "$dir" ]] && [[ -d "$dir" ]]; then
        return 0
    fi
    
    return 1
}

# Check sudo privileges and auto-re-execute if needed
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
    
    # Preserve arguments and environment
    sudo -E "$0" "$@"
    exit $?
}
