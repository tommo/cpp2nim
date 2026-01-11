#!/bin/bash
# Generate Nim bindings for LDtkLoader
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "upstream" ]; then
    echo "Error: Run ./setup.sh first"
    exit 1
fi

echo "Generating bindings..."
cpp2nim all --config=config.json \
    "upstream/include/LDtkLoader/*.hpp" \
    "upstream/include/LDtkLoader/containers/*.hpp" \
    "upstream/include/LDtkLoader/defs/*.hpp"

echo "Done. Output in ./output/"
