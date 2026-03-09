#!/usr/bin/env bash

# Akashic Records One-Command Runner
# Usage: curl -sL https://raw.githubusercontent.com/TinorNoah/Akashic-Records/master/run.sh | bash

set -e

REPO_URL="https://github.com/TinorNoah/Akashic-Records.git"
INSTALL_DIR="$HOME/.akashic-records"

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "\033[0;31m[ERROR]\033[0m git is not installed. Please install git before proceeding."
    exit 1
fi

echo -e "\033[0;34m[INFO]\033[0m Fetching Akashic Records..."

if [ -d "$INSTALL_DIR" ]; then
    # Directory exists, try to update it
    echo -e "\033[0;34m[INFO]\033[0m Updating existing installation at $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull --quiet || {
        echo -e "\033[1;33m[WARN]\033[0m Failed to update via git pull. Proceeding with existing version."
    }
else
    # Clone the repository
    echo -e "\033[0;34m[INFO]\033[0m Cloning repository to $INSTALL_DIR..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi

# Ensure the script is executable
chmod +x "$INSTALL_DIR/akashic_records.sh"

# Run the utility
echo -e "\033[0;32m[SUCCESS]\033[0m Launching Akashic Records..."
cd "$INSTALL_DIR"
exec ./akashic_records.sh
