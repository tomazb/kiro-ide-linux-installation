#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Verification helpers: SHA256 checksums and (optional) signature verification
# Requires: log.sh, net.sh

kiro_sha256() {
  local file="$1"
  sha256sum "${file}" | awk '{print tolower($1)}'
}

kiro_parse_checksum_file() {
  # Extract the first 64-hex digest from a checksum file/string
  local file="$1"
  grep -oE '[A-Fa-f0-9]{64}' "${file}" | head -n1 | tr 'A-F' 'a-f'
}

kiro_resolve_checksum_arg() {
  # Accepts: a hex digest, a file path, file:/path, or url:https://...
  local arg="$1"
  if [[ -z "${arg}" ]]; then
    return 1
  fi
  if [[ "${arg}" =~ ^[A-Fa-f0-9]{64}$ ]]; then
    echo "${arg}" | tr 'A-F' 'a-f'
    return 0
  fi
  if [[ "${arg}" =~ ^file:(.+)$ ]]; then
    local p
    p="${BASH_REMATCH[1]}"
    [[ -f "${p}" ]] || { log_error "checksum file not found: ${p}"; return 1; }
    kiro_parse_checksum_file "${p}"
    return 0
  fi
  if [[ "${arg}" =~ ^url:(.+)$ ]]; then
    local url tmp
    url="${BASH_REMATCH[1]}"
    tmp=$(mktemp -t kiro.chk.XXXXXX)
    trap 'rm -f "'"${tmp}"'"' RETURN
    if ! kiro_net_download "${url}" "${tmp}" 5; then
      log_error "failed to download checksum from ${url}"
      return 1
    fi
    kiro_parse_checksum_file "${tmp}"
    return 0
  fi
  # Otherwise treat as path
  if [[ -f "${arg}" ]]; then
    kiro_parse_checksum_file "${arg}"
    return 0
  fi
  log_error "Unrecognized checksum argument: ${arg}"
  return 1
}

kiro_fetch_remote_checksum_for_url() {
  # Try common patterns: <url>.sha256, <url>.sha256sum
  local base_url="$1"
  local tmp
  tmp=$(mktemp -t kiro.chk.XXXXXX)
  trap 'rm -f "'"${tmp}"'"' RETURN
  local candidate
  for candidate in "${base_url}.sha256" "${base_url}.sha256sum"; do
    if kiro_net_download "${candidate}" "${tmp}" 3 2>/dev/null; then
      local digest
      digest=$(kiro_parse_checksum_file "${tmp}")
      if [[ -n "${digest}" ]]; then
        echo "${digest}"
        return 0
      fi
    fi
  done
  return 1
}

kiro_verify_archive() {
  local archive="$1"; shift
  local source_url="$1"; shift

  if [[ "${KIRO_SKIP_VERIFY:-false}" == true ]]; then
    log_warn "Checksum verification skipped (--skip-verify)"
    return 0
  fi

  local expected=""
  if [[ -n "${KIRO_CHECKSUM:-}" ]]; then
    expected=$(kiro_resolve_checksum_arg "${KIRO_CHECKSUM}") || true
  fi
  if [[ -z "${expected}" ]]; then
    expected=$(kiro_fetch_remote_checksum_for_url "${source_url}") || true
  fi
  if [[ -z "${expected}" ]]; then
    log_warn "No checksum available for ${source_url}. Consider providing --checksum or use --skip-verify to bypass."
    return 0
  fi

  local actual
  actual=$(kiro_sha256 "${archive}")
  if [[ "${actual}" != "${expected}" ]]; then
    log_error "Checksum mismatch for ${archive}: expected ${expected}, got ${actual}"
    return 1
  fi
  log_info "Checksum OK (${actual})"
}

