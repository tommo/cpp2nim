#!/bin/bash
# Generate Nim bindings for MicroPather
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "upstream" ]; then
    echo "Error: Run ./setup.sh first"
    exit 1
fi

echo "Generating bindings..."
cpp2nim all --config=config.json upstream/micropather.h

echo "Done. Output in ./output/"
