
#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Verification helpers: SHA256 checksums and (optional) signature verification
# Requires: log.sh, net.sh, jq, openssl

# Extract signature and certificate from metadata file if available
# Expects KIRO_METADATA_FILE to be set, and tries to match the release by URL
kiro_extract_signature_from_metadata() {
  local source_url="$1"
  local meta_file="${KIRO_METADATA_FILE:-}"
  [[ -f "${meta_file}" ]] || return 1
  # Try common field names
  local sig_b64
  local cert_pem
  sig_b64=$(jq -r --arg url "${source_url}" '.releases[] | select(.updateTo.url==$url) | (.updateTo.signature // .signature // empty)' "${meta_file}" | head -n1)
  cert_pem=$(jq -r '(.certificatePem // .certificate // empty)' "${meta_file}" | head -n1)
  if [[ -n "${sig_b64}" && -n "${cert_pem}" && "${sig_b64}" != "null" && "${cert_pem}" != "null" ]]; then
    KIRO_SIGNATURE_B64="${sig_b64}"
    KIRO_CERT_PEM_CONTENT="${cert_pem}"
    return 0
  fi
  return 1
}

# Verify signature using either provided env vars or metadata
# Inputs (env or metadata): KIRO_SIGNATURE_B64 (base64), KIRO_CERT_PEM_CONTENT (PEM content)
kiro_verify_signature() {
  local archive="$1"; shift
  local source_url="$1"; shift

  # Prefer explicit env overrides if set; otherwise attempt extraction from metadata
  if [[ -z "${KIRO_SIGNATURE_B64:-}" || -z "${KIRO_CERT_PEM_CONTENT:-}" ]]; then
    kiro_extract_signature_from_metadata "${source_url}" || true
  fi
  if [[ -z "${KIRO_SIGNATURE_B64:-}" || -z "${KIRO_CERT_PEM_CONTENT:-}" ]]; then
    # No signature info available
    return 1
  fi

  local tmp_cert tmp_sig
  tmp_cert=$(mktemp -t kiro.cert.XXXXXX)
  tmp_sig=$(mktemp -t kiro.sig.XXXXXX)
  trap 'rm -f "'"${tmp_cert}"' "'"${tmp_sig}"'"' RETURN

  printf '%s\n' "${KIRO_CERT_PEM_CONTENT}" >"${tmp_cert}"
  printf '%s' "${KIRO_SIGNATURE_B64}" | base64 -d >"${tmp_sig}" 2>/dev/null || {
    log_error "Failed to base64-decode signature"
    return 1
  }

  # Extract pubkey
  local tmp_pub
  tmp_pub=$(mktemp -t kiro.pub.XXXXXX)
  trap 'rm -f "'"${tmp_cert}"' "'"${tmp_sig}"' "'"${tmp_pub}"'"' RETURN
  openssl x509 -in "${tmp_cert}" -pubkey -noout >"${tmp_pub}" 2>/dev/null || {
    log_error "Failed to parse public key from certificate"
    return 1
  }

  # Try sha512 then sha256
  if openssl dgst -sha512 -verify "${tmp_pub}" -signature "${tmp_sig}" "${archive}" >/dev/null 2>&1; then
    log_info "Signature OK (sha512)"
    return 0
  fi
  if openssl dgst -sha256 -verify "${tmp_pub}" -signature "${tmp_sig}" "${archive}" >/dev/null 2>&1; then
    log_info "Signature OK (sha256)"
    return 0
  fi

  log_error "Signature verification failed"
  return 1
}

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
    log_warn "Checksum/signature verification skipped (--skip-verify)"
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
  else
    local actual
    actual=$(kiro_sha256 "${archive}")
    if [[ "${actual}" != "${expected}" ]]; then
      log_error "Checksum mismatch for ${archive}: expected ${expected}, got ${actual}"
      return 1
    fi
    log_info "Checksum OK (${actual})"
  fi

  # Attempt signature verification if metadata/cert+sig available
  if ! kiro_verify_signature "${archive}" "${source_url}"; then
    log_warn "Signature verification failed or not available; continuing since checksum matched"
  fi
}

