# Package
version       = "0.1.0"
author        = "PIL"
description   = "C++ to Nim binding generator using libclang"
license       = "MIT"
srcDir        = "src"
bin           = @["cpp2nim_cli"]
binDir        = "bin"

# Dependencies
requires "nim >= 2.0.0"
# Optional: clang >= 0.59 (for parser, use -d:useLibclang)

# Tasks
task test, "Run test suite":
  exec "nim c -r tests/test_all.nim"

task testv, "Run test suite (verbose)":
  exec "nim c -r -d:unittest2Verbose tests/test_all.nim"
