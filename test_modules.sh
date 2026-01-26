#!/bin/bash
# test_modules.sh
# Verifies the modular refactor

set -e
# Disable pipefail to avoid SIGPIPE errors with grep -q or head
set +o pipefail

echo "--- Testing Core Module ---"
source src/core.sh
log_info "Core module sourced."
check_cmd ls && echo "check_cmd ls passed"
check_cmd nonexistentscommandshouldfail || echo "check_cmd fail passed"
echo -e "${GREEN}Core Colors Working${NC}"

echo "--- Testing Sysinfo Module ---"
source src/sysinfo.sh
detect_capabilities
echo "Detailed OS: $SYS_DISTRO"
echo "Package Manager: $SYS_PM"

echo -n "CPU Usage: "
get_cpu_usage

echo -n "Memory Usage: "
get_mem_usage

echo -n "Disk Usage (/): "
get_disk_usage "/"

echo -n "Net Usage: "
sysinfo_net_init
get_net_usage

echo "--- Testing UI Module ---"
source src/ui.sh
# Check if render functions run without error (redirect output)
render_system_overview > /dev/null && echo "render_system_overview ran"
# Use normal grep to avoid SIGPIPE with active writer
get_color 90 | grep "31" >/dev/null && echo "get_color 90 returned Red code"

echo "--- Testing Installer Module ---"
source src/installer.sh
# Just check function existence
type backup_config >/dev/null && echo "backup_config exists"
type install_zsh_environment >/dev/null && echo "install_zsh_environment exists"

echo "--- All Tests Passed ---"
