#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Config loader with precedence: CLI > env > user > system > defaults
# Exposes variables like KIRO_* and paths used by other libs.

# Load defaults.conf first
kiro_config_init() {
  local repo_root
  repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  # shellcheck disable=SC1091
  source "${repo_root}/conf/defaults.conf"

  # Promote defaults into KIRO_* namespace
  : "${KIRO_CHANNEL:=${CHANNEL}}"
  : "${KIRO_TARGET_VERSION:=${TARGET_VERSION}}"
  : "${KIRO_DEFAULT_INSTALL_DIR:=${DEFAULT_INSTALL_DIR}}"
  : "${KIRO_USER_INSTALL_DIR:=${USER_INSTALL_DIR}}"
  : "${KIRO_SYMLINK_DIR_SYSTEM:=${SYMLINK_DIR_SYSTEM}}"
  : "${KIRO_SYMLINK_DIR_USER:=${SYMLINK_DIR_USER}}"
  : "${KIRO_DESKTOP_DIR_SYSTEM:=${DESKTOP_DIR_SYSTEM}}"
  : "${KIRO_DESKTOP_DIR_USER:=${DESKTOP_DIR_USER}}"
  : "${KIRO_STATE_DIR_SYSTEM:=${STATE_DIR_SYSTEM}}"
  : "${KIRO_STATE_DIR_USER:=${STATE_DIR_USER}}"
  : "${KIRO_LOG_FILE_SYSTEM:=${LOG_FILE_SYSTEM}}"
  : "${KIRO_LOG_FILE_USER:=${LOG_FILE_USER}}"
  : "${KIRO_CACHE_DIR:=${CACHE_DIR_DEFAULT}}"
  : "${KIRO_NON_INTERACTIVE:=${NON_INTERACTIVE}}"
  : "${KIRO_DRY_RUN:=${DRY_RUN}}"
  : "${KIRO_VERBOSE:=${VERBOSE}}"
  : "${KIRO_COLOR:=${COLOR}}"
  : "${KIRO_LOG_JSON:=${JSON_LOGS}}"
  : "${KIRO_SKIP_DEPS:=${SKIP_DEPS}}"
  : "${KIRO_SKIP_VERIFY:=${SKIP_VERIFY}}"
  : "${KIRO_SKIP_HOOKS:=${SKIP_HOOKS}}"
  : "${KIRO_METADATA_URL:=${METADATA_URL}}"
}

# Load user and system config files if present
kiro_config_load_files() {
  local user_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/kiro/install.conf"
  local sys_cfg="/etc/kiro/install.conf"
  if [[ -f "${sys_cfg}" ]]; then
    # shellcheck disable=SC1090
    source "${sys_cfg}"
  fi
  if [[ -f "${user_cfg}" ]]; then
    # shellcheck disable=SC1090
    source "${user_cfg}"
  fi
}

# Apply environment overrides (KIRO_*)
kiro_config_apply_env() {
  : "${KIRO_CHANNEL:=${KIRO_CHANNEL}}"
  : "${KIRO_TARGET_VERSION:=${KIRO_TARGET_VERSION}}"
  : "${KIRO_DEFAULT_INSTALL_DIR:=${KIRO_DEFAULT_INSTALL_DIR}}"
  : "${KIRO_USER_INSTALL_DIR:=${KIRO_USER_INSTALL_DIR}}"
  : "${KIRO_CACHE_DIR:=${KIRO_CACHE_DIR}}"
  : "${KIRO_NON_INTERACTIVE:=${KIRO_NON_INTERACTIVE}}"
  : "${KIRO_DRY_RUN:=${KIRO_DRY_RUN}}"
  : "${KIRO_VERBOSE:=${KIRO_VERBOSE}}"
  : "${KIRO_COLOR:=${KIRO_COLOR}}"
  : "${KIRO_LOG_JSON:=${KIRO_LOG_JSON}}"
  : "${KIRO_SKIP_DEPS:=${KIRO_SKIP_DEPS}}"
  : "${KIRO_SKIP_VERIFY:=${KIRO_SKIP_VERIFY}}"
  : "${KIRO_SKIP_HOOKS:=${KIRO_SKIP_HOOKS}}"
  : "${KIRO_METADATA_URL:=${KIRO_METADATA_URL}}"
}

# Derive log level from verbosity
kiro_config_finalize() {
  case "${KIRO_VERBOSE}" in
    0) KIRO_LOG_LEVEL=${KIRO_LOG_LEVEL:-INFO} ;;
    1) KIRO_LOG_LEVEL=${KIRO_LOG_LEVEL:-DEBUG} ;;
    *) KIRO_LOG_LEVEL=${KIRO_LOG_LEVEL:-TRACE} ;;
  esac

  if [[ -w /var/log ]]; then
    KIRO_LOG_FILE=${KIRO_LOG_FILE:-${KIRO_LOG_FILE_SYSTEM}}
  else
    KIRO_LOG_FILE=${KIRO_LOG_FILE:-${KIRO_LOG_FILE_USER}}
  fi
}

# Entry point used by scripts to load config
kiro_config_load() {
  kiro_config_init
  kiro_config_load_files
  kiro_config_apply_env
  kiro_config_finalize
}

