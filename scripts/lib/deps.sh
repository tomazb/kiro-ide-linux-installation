#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Dependency detection and installation
# Validate presence of required tools. Optionally install using the detected PM.

# Requires: log.sh, os.sh, sudo.sh

kiro_deps_require() {
  local -a required=("bash" "curl" "tar" "jq" "sha256sum" "openssl")
  local -a missing=()
  for d in "${required[@]}"; do
    command -v "$d" >/dev/null 2>&1 || missing+=("$d")
  done
  if ((${#missing[@]} == 0)); then
    log_debug "All required dependencies are present"
    return 0
  fi
  if [[ "${KIRO_SKIP_DEPS:-false}" == true ]]; then
    log_error "Missing dependencies: ${missing[*]} (and --skip-deps was set)"
    return 1
  fi

  local pm; pm=$(kiro_os_detect_pm)
  log_info "Installing missing dependencies: ${missing[*]} via ${pm}"
  case "${pm}" in
    apt)   kiro_maybe_sudo apt update -y && kiro_maybe_sudo apt install -y "${missing[@]}" ;;
    dnf)   kiro_maybe_sudo dnf install -y "${missing[@]}" ;;
    yum)   kiro_maybe_sudo yum install -y "${missing[@]}" ;;
    pacman) kiro_maybe_sudo pacman -Sy --needed --noconfirm "${missing[@]}" ;;
    zypper) kiro_maybe_sudo zypper install -y "${missing[@]}" ;;
    *) log_error "Unknown package manager; please install: ${missing[*]}"; return 1 ;;
  esac
}

