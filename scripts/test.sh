#!/bin/bash
set -e
cd "$(dirname "$0")/.."

PROFRAW="default.profraw"
PROFDATA="/tmp/wesafechat.profdata"
TEST_BIN="/tmp/wesafechat_tests"
COV_DIR="src/logic"

rm -f "$PROFRAW"

echo "==> Compiling tests..."
swiftc \
    tests/main.swift \
    tests/TestCore.swift \
    tests/TestMigration.swift \
    src/logic/Core.swift \
    src/logic/Migration.swift \
    -profile-generate \
    -profile-coverage-mapping \
    -o "$TEST_BIN"

echo "==> Running tests..."
"$TEST_BIN"

echo
echo "==> Coverage..."
xcrun llvm-profdata merge "$PROFRAW" -o "$PROFDATA"
xcrun llvm-cov report "$TEST_BIN" -instr-profile="$PROFDATA" \
    -ignore-filename-regex="tests/"

echo
echo "==> Checking $COV_DIR/ is 100%..."
MISSED=$(xcrun llvm-cov report "$TEST_BIN" -instr-profile="$PROFDATA" \
    -ignore-filename-regex="tests/" \
    | awk -v dir="$COV_DIR" '$1 ~ dir {sum+=$4} END {print sum+0}')

rm -f "$PROFRAW" "$PROFDATA"

if [ "$MISSED" -gt 0 ]; then
    echo "FAIL: $COV_DIR/ has $MISSED uncovered line(s). 100% coverage required."
    exit 1
fi
echo "PASS: $COV_DIR/ is 100% covered."
