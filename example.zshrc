# --- Shell Options, History & Keybindings ---
HISTFILE=~/.config/zsh/.histfile
HISTSIZE=5000
SAVEHIST=100000
setopt autocd extendedglob
unsetopt beep
bindkey -e # Use vi keybindings in command mode

# Ensure user's local bin is in PATH (for pipx and thefuck)
export PATH="$HOME/.local/bin:$PATH"

# --- Initialize Shell Tools ---
eval "$(zoxide init zsh)"

# --- Aliases ---
alias ls="lsd"
alias l="lsd -l"
alias la="lsd -a"
alias lla="lsd -la"
alias lt="lsd --tree"
alias cd="z"

# --- Zsh Autosuggestions (from apt) ---
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Starship Prompt
eval "$(starship init zsh)"

# --- FZF Keybindings ---
source /usr/share/doc/fzf/examples/key-bindings.zsh

# --- Zsh Syntax Highlighting (must be sourced last) ---
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- Zsh Autocomplete (must be sourced before compinit) ---
source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh

# --- Initialize Zsh Completion System ---
autoload -U compinit && compinit