#!/bin/bash
# Setup script for MicroPather example
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

REPO_URL="https://github.com/leethomason/MicroPather.git"
REPO_DIR="upstream"

if [ -d "$REPO_DIR" ]; then
    echo "Updating existing repo..."
    cd "$REPO_DIR"
    git pull
else
    echo "Cloning MicroPather..."
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

echo "Setup complete. Run ./generate.sh to generate bindings."
