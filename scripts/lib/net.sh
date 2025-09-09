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

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry "${retries}" --retry-all-errors --connect-timeout 10 -o "${out}" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${out}" "${url}"
  else
    log_error "Neither curl nor wget is available"
    return 1
  fi
}

