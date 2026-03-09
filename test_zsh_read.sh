if [ -n "$ZSH_VERSION" ]; then
  read -t 0.1 -k 1 input || true
else
  read -t 0.1 -n 1 input || true
fi
