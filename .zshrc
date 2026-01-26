# ===============================
# ZSH Base Configuration
# ===============================

# The following lines were added by compinstall

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' menu select=0
zstyle ':completion:*' original true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle :compinstall filename "$HOME/.zshrc"

autoload -Uz compinit
compinit

# End of lines added by compinstall


# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=100000
setopt autocd extendedglob nomatch notify
bindkey -e
# End of lines configured by zsh-newuser-install


# ===============================
# Plugin Configuration Blocks
# Managed by gather_sys_info.sh
# ===============================

# >>> plugin:starship >>>
eval "$(starship init zsh)"
# <<< plugin:starship <<<


# >>> plugin:zsh-autosuggestions >>>
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
# <<< plugin:zsh-autosuggestions <<<


# >>> plugin:zsh-autocomplete >>>
if [ -f "$HOME/.zshplugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]; then
  source "$HOME/.zshplugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
fi
# <<< plugin:zsh-autocomplete <<<


# >>> plugin:zsh-syntax-highlighting >>>
# MUST be last plugin sourced
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
# <<< plugin:zsh-syntax-highlighting <<<


# ===============================
# User Environment
# ===============================

# Add necessary SDK tool directories to the system PATH
export PATH="$HOME/.local/bin:$PATH"

