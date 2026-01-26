#!/bin/bash
# src/installer.sh
# Installation and Configuration logic

# Ensure dependencies
if [[ -z "${NC:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/core.sh" ]]; then source "$SCRIPT_DIR/core.sh"; fi
    if [[ -f "$SCRIPT_DIR/sysinfo.sh" ]]; then source "$SCRIPT_DIR/sysinfo.sh"; fi
fi

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


# 12. Setup Shell (Detailed & Robust)
install_zsh_environment() {
    # Detect Real User (if running as sudo)
    local real_user="${SUDO_USER:-$USER}"
    local real_home
    if [[ "$real_user" == "root" ]]; then
        # Fallback if we are just root without sudo
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
        if [[ "$is_present" -eq 1 ]]; then
             read -p "$(echo -e "  [${GREEN}x${NC}] $desc is already installed. Enable/Update in .zshrc? (Y/n): ")" choice
        else
             read -p "$(echo -e "  [ ] Install $desc? (Y/n): ")" choice
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
        if [[ "${selected_components[$name]:-0}" -eq 1 ]]; then
             echo -e "${BOLD}$desc${NC}: ${GREEN}Install/Configure${NC} [${CAPABILITY_MATRIX[$name]}]"
        else
             echo -e "${BOLD}$desc${NC}: ${CYAN}Skip (exclude from .zshrc)${NC}"
        fi
    done
    
    if [[ "$IS_DRY_RUN" -eq 1 ]]; then
        echo -e "${YELLOW}[DRY-RUN] No changes will be executed.${NC}"
        # pause # Assuming pause is in ui.sh which might not be sourced if running standalone?
        # But we sourced core/sysinfo to ensure environment.
        return
    fi
      
    echo ""
    read -p "Proceed with changes? (Y/n): " confirm
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
        if [[ "${selected_components[$name]:-0}" != 1 ]]; then continue; fi
        
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
    # Adjust for modular structure: src/../.zshrc
    local template_zshrc="$(dirname "${BASH_SOURCE[0]}")/../.zshrc"
    if [[ ! -f "$template_zshrc" ]]; then
        # Try finding it in current dir if not in parent (standalone run vs project struct)
        if [[ -f ".zshrc" ]]; then
            template_zshrc=".zshrc"
        else
            log_error "Template .zshrc not found at $template_zshrc"
            return 1
        fi
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
        read -p "Start Zsh now? (Replaces current shell) (Y/n): " start_zsh
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
}
