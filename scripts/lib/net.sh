#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Network helpers for downloading files with retry and cache support

# Resolve CA bundle path if provided via KIRO_CA_BUNDLE (supports file: or direct path)
kiro_net_resolve_ca_bundle() {
  local val="${KIRO_CA_BUNDLE:-}"
  if [[ -z "${val}" ]]; then
    return 1
  fi
  if [[ "${val}" =~ ^file:(.+)$ ]]; then
    val="${BASH_REMATCH[1]}"
  fi
  if [[ -f "${val}" ]]; then
    printf '%s\n' "${val}"
    return 0
  fi
  log_warn "KIRO_CA_BUNDLE is set but not a readable file: ${KIRO_CA_BUNDLE}"
  return 1
}

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

  local ca_path=""
  ca_path=$(kiro_net_resolve_ca_bundle || true)

  if command -v curl >/dev/null 2>&1; then
    # Build curl args
    local -a args=("-fsSL" "--retry" "${retries}" "--retry-all-errors" "--connect-timeout" "10")
    if [[ -n "${ca_path}" ]]; then
      args+=("--cacert" "${ca_path}")
    fi
    # For HTTPS, enforce protocol; otherwise let curl handle (e.g., http if allowed)
    if [[ "${url}" =~ ^https:// ]]; then
      args=("--proto" "=https" "${args[@]}")
    fi
    args+=("-o" "${out}" "${url}")
    curl "${args[@]}"
  elif command -v wget >/dev/null 2>&1; then
    local -a args=("-q")
    if [[ -n "${ca_path}" ]]; then
      args+=("--ca-certificate=${ca_path}")
    fi
    args+=("-O" "${out}" "${url}")
    wget "${args[@]}"
  else
    log_error "Neither curl nor wget is available"
    return 1
  fi
}

