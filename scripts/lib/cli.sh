#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# CLI parsing library using getopt where available, with fallback.
# Converts args into KIRO_* vars for the rest of the system.

# Usage: kiro_cli_parse "$@"
kiro_cli_parse() {
  local -a args=("$@")

  local short_opts="hyvq"
  local long_opts="help,install,update,uninstall,user,force,clean,dry-run,non-interactive,yes,config:,cache-dir:,state-dir:,log-level:,no-color,json-logs,checksum:,sig:,cert:,package:,skip-deps,skip-verify,skip-hooks,channel:,version:,prefix:"

  if getopt --test >/dev/null 2>&1; then
    local parsed
    parsed=$(getopt -o "${short_opts}" -l "${long_opts}" -n kiro -- "${args[@]}" 2>/dev/null) || {
      echo "Failed to parse arguments" >&2
      return 2
    }
    # shellcheck disable=SC2086
    eval set -- ${parsed}
  else
    # Very simple fallback: iterate args
    set -- "${args[@]}"
  fi

  # Defaults
  ACTION="install"
  USER_ONLY=false
  FORCE_UPDATE=false
  CLEAN_UNINSTALL=false
  KIRO_NON_INTERACTIVE=${KIRO_NON_INTERACTIVE:-false}

  while true; do
    case "${1:-}" in
      --) shift; break ;;
      -h|--help) ACTION="help"; shift ;;
      --install|--update) ACTION="install"; shift ;;
      --uninstall) ACTION="uninstall"; shift ;;
      --user) USER_ONLY=true; shift ;;
      --force) FORCE_UPDATE=true; shift ;;
      --clean) CLEAN_UNINSTALL=true; shift ;;
      -y|--non-interactive|--yes) KIRO_NON_INTERACTIVE=true; shift ;;
      --dry-run) KIRO_DRY_RUN=true; shift ;;
      -v) KIRO_VERBOSE=$(( ${KIRO_VERBOSE:-0} + 1 )); shift ;;
      -q) KIRO_VERBOSE=0; KIRO_LOG_LEVEL=ERROR; shift ;;
      --config) KIRO_CONFIG_PATH="$2"; shift 2 ;;
      --cache-dir) KIRO_CACHE_DIR="$2"; shift 2 ;;
      --state-dir) KIRO_STATE_DIR_OVERRIDE="$2"; shift 2 ;;
      --log-level) KIRO_LOG_LEVEL="$2"; shift 2 ;;
      --no-color) KIRO_COLOR=never; shift ;;
      --json-logs) KIRO_LOG_JSON=true; shift ;;
      --checksum) KIRO_CHECKSUM="$2"; shift 2 ;;
      --sig) KIRO_SIG="$2"; shift 2 ;;
      --cert) KIRO_CERT="$2"; shift 2 ;;
      --package) KIRO_PACKAGE_LOCAL="$2"; shift 2 ;;
      --skip-deps) KIRO_SKIP_DEPS=true; shift ;;
      --skip-verify) KIRO_SKIP_VERIFY=true; shift ;;
      --skip-hooks) KIRO_SKIP_HOOKS=true; shift ;;
      --channel) KIRO_CHANNEL="$2"; shift 2 ;;
      --version) KIRO_TARGET_VERSION="$2"; shift 2 ;;
      --prefix) KIRO_PREFIX_OVERRIDE="$2"; shift 2 ;;
      *) break ;;
    esac
  done

  # Remaining args are positional (unused for now)
  REMAINS=("$@")
}

