#!/bin/bash
# Run cpp2nim tests
# Usage: ./scripts/test.sh [parser|codegen|unit|all]

set -e
cd "$(dirname "$0")/.."

CLANG_LIB="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib"

case "${1:-all}" in
  parser)
    echo "Building parser tests..."
    nim c -d:useLibclang --passL:"-L$CLANG_LIB -lclang" -o:_build/debug/test_parser tests/test_parser.nim
    echo "Running parser tests..."
    DYLD_LIBRARY_PATH=$CLANG_LIB ./_build/debug/test_parser
    ;;
  codegen)
    echo "Building codegen tests..."
    nim c -d:useLibclang --passL:"-L$CLANG_LIB -lclang" -o:_build/debug/test_codegen tests/test_codegen.nim
    echo "Running codegen tests (nim check validation)..."
    DYLD_LIBRARY_PATH=$CLANG_LIB ./_build/debug/test_codegen
    ;;
  unit)
    echo "Building unit tests (no libclang)..."
    nim c -r tests/test_all.nim
    ;;
  all)
    echo "Building all tests..."
    nim c -d:useLibclang --passL:"-L$CLANG_LIB -lclang" -o:_build/debug/test_all tests/test_all.nim
    echo "Running all tests..."
    DYLD_LIBRARY_PATH=$CLANG_LIB ./_build/debug/test_all
    ;;
  *)
    echo "Usage: $0 [parser|codegen|unit|all]"
    exit 1
    ;;
esac
