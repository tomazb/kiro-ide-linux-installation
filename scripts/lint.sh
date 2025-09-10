#!/usr/bin/env bash
# Lint helper to keep CI and local usage DRY
set -euo pipefail

# Allow making shfmt formatting non-fatal (default: non-fatal to avoid noisy CI)
SHFMT_STRICT=${SHFMT_STRICT:-false}

if ! command -v shfmt >/dev/null 2>&1; then
  echo "shfmt not found. Install it (e.g., sudo apt-get install -y shfmt)" >&2
  exit 1
fi
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not found. Install it (e.g., sudo apt-get install -y shellcheck)" >&2
  exit 1
fi

# Format check
if [ "${SHFMT_STRICT}" = "true" ]; then
  shfmt -d -i 2 -ci -bn . || { echo "Run: shfmt -w -i 2 -ci -bn ."; exit 1; }
else
  fmt_list=$(shfmt -l -i 2 -ci -bn .)
  if [ -n "${fmt_list}" ]; then
    echo "The following files need formatting (informational):" >&2
    echo "${fmt_list}" >&2
    echo "Run: shfmt -w -i 2 -ci -bn ." >&2
  fi
fi

# ShellCheck
mapfile -t FILES < <(find . -type f -name "*.sh" -not -path "*/node_modules/*" -not -path "*/vendor/*")
if [ ${#FILES[@]} -eq 0 ]; then
  echo "No .sh files found"
  exit 0
fi
# Use warning severity to gate CI on substantive issues; style suggestions remain visible locally
shellcheck -S warning -x "${FILES[@]}"

