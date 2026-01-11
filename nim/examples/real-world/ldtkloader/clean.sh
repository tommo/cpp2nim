#!/bin/bash
# Clean generated files
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf output parsed
echo "Cleaned output and parsed directories."
