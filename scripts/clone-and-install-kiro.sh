#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Compatibility wrapper that clones (if needed) and delegates to scripts/install-kiro.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."

REPO_URL_DEFAULT="https://github.com/tomazb/kiro-ide-linux-installation"

print_usage() {
  cat <<'USAGE'
Usage: clone-and-install-kiro.sh [INSTALLER_OPTIONS]
Clones the installer repo into a temp dir (or updates if present) and runs scripts/install-kiro.sh.
All options are forwarded to the installer.
USAGE
}

main() {
  local repo_url="${REPO_URL_DEFAULT}"
  local tmp_dir
  tmp_dir=$(mktemp -d -t kiro-install-src.XXXXXX)
  trap 'rm -rf "${tmp_dir}"' EXIT

  echo "Cloning ${repo_url} to ${tmp_dir}..."
  if ! git clone --depth=1 "${repo_url}" "${tmp_dir}"; then
    echo "Failed to clone repo: ${repo_url}" >&2
    exit 1
  fi

  # Delegate to refactored installer
  exec bash "${tmp_dir}/scripts/install-kiro.sh" "$@"
}

main "$@"

