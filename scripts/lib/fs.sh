#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Filesystem helpers: temp dirs, atomic writes, locks

: "${KIRO_UMASK:=022}"
umask "${KIRO_UMASK}"

kiro_fs_mktmpdir() {
  local tmp
  tmp=$(mktemp -d -t kiro.XXXXXX)
  chmod 700 "${tmp}"
  printf '%s\n' "${tmp}"
}

# Atomic write: write stdin to temp file then move into place
kiro_fs_atomic_write() {
  local target="$1"
  local dir; dir=$(dirname -- "${target}")
  mkdir -p -- "${dir}"
  local tmp
  tmp=$(mktemp -p "${dir}" .kiro.tmp.XXXXXX)
  cat > "${tmp}"
  mv -f -- "${tmp}" "${target}"
}

# Flock-based global lock
kiro_fs_acquire_lock() {
  local lock_path="$1"
  exec {KIRO_LOCK_FD}>"${lock_path}"
  flock -n ${KIRO_LOCK_FD} || {
    echo "Another Kiro operation is in progress (lock: ${lock_path})" >&2
    return 1
  }
}

kiro_fs_release_lock() {
  if [[ -n "${KIRO_LOCK_FD:-}" ]]; then
    flock -u ${KIRO_LOCK_FD} || true
    eval "exec ${KIRO_LOCK_FD}>&-" || true
  fi
}

