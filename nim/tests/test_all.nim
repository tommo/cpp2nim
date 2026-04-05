## Test runner for cpp2nim.
##
## Run with: nim c -d:useLibclang -r tests/test_all.nim
## Or use: nimble test

import std/[unittest, strutils]

# Import all test modules
import test_utils
import test_types
import test_config
import test_models

when defined(useLibclang):
  import test_parser
  import test_codegen

when isMainModule:
  echo repeat("=", 60)
  echo "Running cpp2nim test suite"
  echo repeat("=", 60)
  echo ""

  # Tests are run automatically by unittest when imported
  # This file just aggregates them

  echo ""
  echo repeat("=", 60)
  echo "All tests completed"
  echo repeat("=", 60)
