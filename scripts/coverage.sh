#!/usr/bin/env bash
set -e

# Run tests with code coverage enabled
echo "Running unit tests with code coverage..."
swift test --enable-code-coverage

# Locate profdata and test executable
PROFDATA=$(find .build -name "default.profdata" | head -n 1)
EXECUTABLE=$(find .build -name "ZxingKitPackageTests" -type f | grep -v "\.dSYM" | head -n 1)

if [ -z "$PROFDATA" ] || [ -z "$EXECUTABLE" ]; then
  echo "Error: Could not find profdata or test executable."
  exit 1
fi

echo "========================================================================="
echo "                     ZxingKit Code Coverage Report                       "
echo "========================================================================="
xcrun llvm-cov report "$EXECUTABLE" -instr-profile="$PROFDATA" --ignore-filename-regex="\.build|third_party|Tests"

# Optional: Generate HTML report if --html flag is passed
if [ "$1" == "--html" ]; then
  OUTPUT_DIR=".build/codecov/html"
  xcrun llvm-cov show "$EXECUTABLE" -instr-profile="$PROFDATA" --ignore-filename-regex="\.build|third_party|Tests" -format=html -output-dir="$OUTPUT_DIR"
  echo "HTML coverage report generated at: file://$(pwd)/$OUTPUT_DIR/index.html"
fi
