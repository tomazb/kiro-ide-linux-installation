#!/usr/bin/env bash
# Lint helper to keep CI and local usage DRY
set -euo pipefail

if ! command -v shfmt >/dev/null 2>&1; then
  echo "shfmt not found. Install it (e.g., sudo apt-get install -y shfmt)" >&2
  exit 1
fi
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not found. Install it (e.g., sudo apt-get install -y shellcheck)" >&2
  exit 1
fi

# Format check
shfmt -d -i 2 -ci -bn . || { echo "Run: shfmt -w -i 2 -ci -bn ."; exit 1; }

# ShellCheck
mapfile -t FILES < <(find . -type f -name "*.sh" -not -path "*/node_modules/*" -not -path "*/vendor/*")
if [ ${#FILES[@]} -eq 0 ]; then
  echo "No .sh files found"
  exit 0
fi
shellcheck -S style -x "${FILES[@]}"

