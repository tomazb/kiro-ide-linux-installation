#!/usr/bin/env bash
# Simple test runner. Runs bats if available, otherwise prints guidance.
set -euo pipefail

if command -v bats >/dev/null 2>&1; then
  echo "Running bats unit tests..."
  bats tests/unit
  unit_rc=$?
  if [ -d tests/integration ]; then
    echo "Running bats integration tests..."
    bats tests/integration || exit $?
  fi
  exit $unit_rc
else
  echo "bats not found. To run unit tests, install it:"
  echo "  sudo dnf install -y bats" 
  echo "or use your distro's package manager."
  exit 0
fi

