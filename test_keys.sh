read_key() {
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
    echo "Escape sequence: $input" | cat -v
  else
    echo "Key: $input" | cat -v
  fi
}
echo "Press an arrow key..."
# test_keys.sh
