#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Orchestrator entrypoint (refactored). Thin wrapper that delegates to libs.
# Backward compatible with existing flags and behavior.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load libs
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/log.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/cli.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/os.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/sudo.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/deps.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/fs.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/net.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/version.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/state.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/verify.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/installer.sh"

print_header() {
  log_info "======================================"
  log_info "        Kiro Installer (refactored)   "
  log_info "======================================"
}

print_usage() {
  cat <<'USAGE'
Usage: install-kiro.sh [OPTIONS]
  --install | --update       Install or update Kiro (default)
  --uninstall                Uninstall Kiro
  --user                     Operate in user mode
  --force                    Force reinstall
  --clean                    Clean user data on uninstall
  -y, --non-interactive      Do not prompt for confirmation
  --dry-run                  Simulate actions without changes
  -v                         Increase verbosity (repeatable)
  -q                         Quiet (errors only)
  --no-color                 Disable colored output
  --json-logs                Emit JSON logs
  --cache-dir PATH           Cache directory
  --state-dir PATH           State directory override
  --log-level LEVEL          TRACE|DEBUG|INFO|WARN|ERROR
  --channel NAME             stable|beta|edge
  --version X.Y.Z            Target version
  --prefix PATH              Install prefix override
  --help                     Show this help
USAGE
}

main() {
  local ORIG_ARGS=("$@")
  kiro_config_load
  kiro_cli_parse "${ORIG_ARGS[@]}"

  print_header

  if [[ "${ACTION}" == "help" ]]; then
    print_usage
    return 0
  fi

  # Resolve context
  if [[ "${USER_ONLY}" == true ]]; then
    INSTALL_PREFIX="${KIRO_USER_INSTALL_DIR}"
    SYMLINK_DIR="${KIRO_SYMLINK_DIR_USER}"
    DESKTOP_DIR="${KIRO_DESKTOP_DIR_USER}"
    NEED_SUDO=false
  else
    INSTALL_PREFIX="${KIRO_DEFAULT_INSTALL_DIR}"
    SYMLINK_DIR="${KIRO_SYMLINK_DIR_SYSTEM}"
    DESKTOP_DIR="${KIRO_DESKTOP_DIR_SYSTEM}"
    NEED_SUDO=true
  fi

  # Preflight deps
  kiro_deps_require

  # Acquire lock
  local lock_path
  if [[ "${USER_ONLY}" == true ]]; then
    lock_path="${XDG_RUNTIME_DIR:-/tmp}/kiro-install.lock"
  else
    lock_path="/var/lock/kiro-install.lock"
    [[ -w "$(dirname "${lock_path}")" ]] || lock_path="/tmp/kiro-install.lock"
  fi
  if ! kiro_fs_acquire_lock "${lock_path}"; then
    log_error "Failed to acquire lock at ${lock_path}"
    return 1
  fi
  trap 'kiro_fs_release_lock' EXIT ERR INT TERM

  case "${ACTION}" in
    uninstall)
      kiro_uninstall_main "${USER_ONLY}" "${CLEAN_UNINSTALL}"
      ;;
    install)
      kiro_install_main "${USER_ONLY}" "${FORCE_UPDATE}"
      ;;
    *)
      log_error "Unknown action: ${ACTION}"
      return 2
      ;;
  esac

  log_info "Done"
}

main "$@"

