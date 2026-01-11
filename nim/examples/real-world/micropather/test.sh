#!/bin/bash
# Test that generated bindings compile
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "output" ]; then
    echo "Error: Run ./generate.sh first"
    exit 1
fi

echo "Testing bindings compile..."
nim check test.nim

echo "Test passed."
