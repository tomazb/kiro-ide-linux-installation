#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# State management helper: record installation actions for idempotency

kiro_state_dir() {
  if [[ -w /var/lib ]]; then
    printf '%s\n' "${KIRO_STATE_DIR_SYSTEM:-/var/lib/kiro}"
  else
    printf '%s\n' "${KIRO_STATE_DIR_USER:-${XDG_STATE_HOME:-$HOME/.local/state}/kiro}"
  fi
}

kiro_state_file() {
  printf '%s/install-state.json\n' "$(kiro_state_dir)"
}

kiro_state_write() {
  local json="$1"
  local file; file=$(kiro_state_file)
  mkdir -p "$(dirname -- "${file}")"
  printf '%s\n' "${json}" > "${file}"
}

