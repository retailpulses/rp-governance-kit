#!/usr/bin/env bash
# Governance kit test runner
# Run all test suites against the governance kit.
# Usage: tests/run.sh [--suite <name>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASSED=0
FAILED=0
TESTS=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
  PASSED=$((PASSED + 1))
  echo -e "  ${GREEN}PASS${NC} $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo -e "  ${RED}FAIL${NC} $1"
}

warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"
}

run_suite() {
  local suite="$1"
  echo ""
  echo "=== $suite ==="
  if [[ -f "$SCRIPT_DIR/$suite" ]]; then
    TESTS+=("$suite")
    cd "$KIT_DIR"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/$suite"
  else
    fail "Test suite not found: $suite"
  fi
}

all_suites() {
  for f in "$SCRIPT_DIR"/test_*.sh; do
    [[ -f "$f" ]] || continue
    local name
    name=$(basename "$f")
    run_suite "$name"
  done
}

if [[ $# -gt 0 ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --suite)
        [[ $# -ge 2 ]] || { echo "Error: --suite requires a name" >&2; exit 1; }
        run_suite "$2"
        shift 2
        ;;
      --help|-h)
        echo "Usage: tests/run.sh [--suite <name>]"
        echo ""
        echo "Available suites:"
        for f in "$SCRIPT_DIR"/test_*.sh; do
          [[ -f "$f" ]] && echo "  $(basename "$f")"
        done
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
else
  all_suites
fi

echo ""
echo "========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
