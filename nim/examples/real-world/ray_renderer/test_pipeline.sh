#!/bin/bash
# Test script for Ray Renderer cpp2nim pipeline
# Proves the full pipeline runs automatically from C++ headers to compilable Nim bindings

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Ray Renderer cpp2nim Pipeline Test"
echo "=========================================="
echo ""

# Step 1: Clean previous output
echo "[1/5] Cleaning previous output..."
rm -rf output/*.nim
echo "  ✓ Cleaned output directory"
echo ""

# Step 2: Build cpp2nim if needed
echo "[2/5] Building cpp2nim..."
cd ../../..
nimble build -y 2>&1 | tail -3
echo "  ✓ cpp2nim_cli ready"
cd "$SCRIPT_DIR"
echo ""

# Step 3: Run cpp2nim with config
echo "[3/5] Generating Nim bindings..."
../../../bin/cpp2nim_cli all --config=config.json \
    headers/Types.h \
    headers/Log.h \
    headers/SceneBase.h \
    headers/RendererBase.h
echo ""

# Step 4: List generated files
echo "[4/5] Generated files:"
for f in output/*.nim; do
    lines=$(wc -l < "$f")
    echo "  - $(basename "$f"): $lines lines"
done
echo ""

# Step 5: Verify all files compile
echo "[5/5] Verifying Nim compilation..."
PASS=0
FAIL=0
for f in output/*.nim; do
    name=$(basename "$f")
    if nim check "$f" 2>&1 | grep -q "SuccessX"; then
        echo "  ✓ $name"
        ((PASS++))
    else
        echo "  ✗ $name FAILED"
        nim check "$f" 2>&1 | grep -E "Error:|error:" | head -3
        ((FAIL++))
    fi
done
echo ""

# Step 6: Check example compiles
echo "[6/6] Verifying example.nim..."
if nim check example.nim 2>&1 | grep -q "SuccessX"; then
    echo "  ✓ example.nim compiles"
else
    echo "  ✗ example.nim FAILED"
    nim check example.nim 2>&1 | grep -E "Error:|error:" | head -5
    ((FAIL++))
fi
echo ""

# Summary
echo "=========================================="
if [ $FAIL -eq 0 ]; then
    echo "SUCCESS: All $PASS binding files + example compile!"
    echo "=========================================="
    exit 0
else
    echo "FAILED: $FAIL file(s) failed to compile"
    echo "=========================================="
    exit 1
fi
