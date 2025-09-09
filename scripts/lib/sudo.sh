#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Sudo helpers. Enforce policy and provide wrappers.

# User rule: always use sudo for virsh operations.
KIRO_ENFORCE_SUDO_VIRSH=true

kiro_maybe_sudo() {
  if [[ "${1:-}" == "virsh" ]] && [[ "${KIRO_ENFORCE_SUDO_VIRSH}" == true ]]; then
    set -- sudo "$@"
  fi
  if command -v sudo >/dev/null 2>&1 && ! kiro_os_is_root; then
    sudo "$@"
  else
    "$@"
  fi
}

