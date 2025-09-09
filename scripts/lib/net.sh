#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Network helpers for downloading files with retry and cache support

kiro_net_download() {
  local url="$1"; shift
  local out="$1"; shift
  local retries=${1:-5}

  mkdir -p "$(dirname -- "${out}")"

  # Handle file: scheme (copy locally)
  if [[ "${url}" =~ ^file:(.+)$ ]]; then
    local src="${BASH_REMATCH[1]}"
    if [[ ! -f "${src}" ]]; then
      log_error "file: URL not found: ${src}"
      return 1
    fi
    cp -f -- "${src}" "${out}"
    return 0
  fi

  # Disallow plain HTTP unless explicitly allowed
  if [[ "${url}" =~ ^http:// ]] && [[ "${KIRO_ALLOW_INSECURE_HTTP:-false}" != true ]]; then
    log_error "Refusing insecure HTTP download: ${url} (set KIRO_ALLOW_INSECURE_HTTP=true to override)"
    return 1
  fi

  if command -v curl >/dev/null 2>&1; then
    # For HTTPS, enforce protocol; otherwise let curl handle (e.g., http if allowed)
    if [[ "${url}" =~ ^https:// ]]; then
      curl --proto =https -fsSL --retry "${retries}" --retry-all-errors --connect-timeout 10 -o "${out}" "${url}"
    else
      curl -fsSL --retry "${retries}" --retry-all-errors --connect-timeout 10 -o "${out}" "${url}"
    fi
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${out}" "${url}"
  else
    log_error "Neither curl nor wget is available"
    return 1
  fi
}

