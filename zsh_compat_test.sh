if [ -n "$ZSH_VERSION" ]; then
    echo "Zsh version: $ZSH_VERSION"
    read_char() { read -rs -k 1 "$1"; }
else
    echo "Bash version: $BASH_VERSION"
    read_char() { read -rsn1 "$1"; }
fi

read_char input < /dev/null || true
