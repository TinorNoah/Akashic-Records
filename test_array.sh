test_menu() {
    local ref="$1"
    local length
    eval "length=\${#${ref}[@]}"
    echo "Length: $length"
    if [ -n "$ZSH_VERSION" ]; then
        echo "Running in Zsh"
        for ((i=1; i<=length; i++)); do
            local item
            eval "item=\"\${${ref}[$i]}\""
            echo "Item Zsh $i: $item"
        done
    else
        echo "Running in Bash"
        for ((i=0; i<length; i++)); do
            local item
            eval "item=\"\${${ref}[$i]}\""
            echo "Item Bash $i: $item"
        done
    fi
}

my_array=("alpha" "beta" "gamma")
test_menu my_array
