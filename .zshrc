# The following lines were added by compinstall

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' menu select=0
zstyle ':completion:*' original true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle :compinstall filename '/home/tinor/.zshrc'

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
eval "$(starship init zsh)"

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /home/tinor/.zshplugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH="$PATH:$HOME/flutter/bin"

# Add necessary SDK tool directories to the system PATH
export PATH=$HOME/.local/bin:$PATH
