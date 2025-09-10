#!/usr/bin/env bash

# Logging library for Kiro installer
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Colors
if [[ -t 1 ]]; then
  _COLOR_SUPPORT=true
else
  _COLOR_SUPPORT=false
fi

_LOG_COLOR_RED='\033[0;31m'
_LOG_COLOR_GREEN='\033[0;32m'
_LOG_COLOR_YELLOW='\033[0;33m'
_LOG_COLOR_BLUE='\033[0;34m'
_LOG_COLOR_DIM='\033[2m'
_LOG_COLOR_RESET='\033[0m'

# Defaults may be overridden by caller
: "${KIRO_LOG_LEVEL:=INFO}"
: "${KIRO_LOG_FILE:=}"
: "${KIRO_COLOR:=auto}"
: "${KIRO_LOG_JSON:=false}"
: "${KIRO_RUN_ID:=$(date +%s)-$$}"

_log_should_color() {
  case "${KIRO_COLOR}" in
    always) echo true ;;
    never) echo false ;;
    auto)
      if ${_COLOR_SUPPORT}; then echo true; else echo false; fi ;;
    *) echo false ;;
  esac
}

_log_level_to_num() {
  case "$1" in
    TRACE) echo 10 ;;
    DEBUG) echo 20 ;;
    INFO)  echo 30 ;;
    WARN)  echo 40 ;;
    ERROR) echo 50 ;;
    *) echo 30 ;;
  esac
}

_log_num_to_label() {
  case "$1" in
    10) echo TRACE ;;
    20) echo DEBUG ;;
    30) echo INFO ;;
    40) echo WARN ;;
    50) echo ERROR ;;
    *) echo INFO ;;
  esac
}

_log_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_log_emit() {
  local level="$1"; shift
  local msg="$*"
  local ts; ts=$(_log_ts)
  local pid="$$"
  local color=false
  color=$(_log_should_color)

  if [[ "${KIRO_LOG_JSON}" == true ]]; then
    local json
    json=$(printf '{"ts":"%s","level":"%s","pid":%d,"run_id":"%s","msg":%s}\n' \
      "${ts}" "${level}" "${pid}" "${KIRO_RUN_ID}" "$(jq -R -s '.' <<<"${msg}")")
    printf '%s' "${json}"
    if [[ -n "${KIRO_LOG_FILE}" ]]; then
      mkdir -p -- "$(dirname -- "${KIRO_LOG_FILE}")" 2>/dev/null || true
      printf '%s' "${json}" >>"${KIRO_LOG_FILE}" || true
    fi
    return 0
  fi

  local line
  if ${color}; then
    case "${level}" in
      TRACE) line="${_LOG_COLOR_DIM}${ts} [TRACE]${_LOG_COLOR_RESET} ${msg}" ;;
      DEBUG) line="${_LOG_COLOR_BLUE}${ts} [DEBUG]${_LOG_COLOR_RESET} ${msg}" ;;
      INFO)  line="${_LOG_COLOR_GREEN}${ts} [INFO ]${_LOG_COLOR_RESET} ${msg}" ;;
      WARN)  line="${_LOG_COLOR_YELLOW}${ts} [WARN ]${_LOG_COLOR_RESET} ${msg}" ;;
      ERROR) line="${_LOG_COLOR_RED}${ts} [ERROR]${_LOG_COLOR_RESET} ${msg}" ;;
      *)     line="${ts} [INFO ] ${msg}" ;;
    esac
  else
    line="${ts} [${level}] ${msg}"
  fi

  printf '%b\n' "${line}"
  if [[ -n "${KIRO_LOG_FILE}" ]]; then
    mkdir -p -- "$(dirname -- "${KIRO_LOG_FILE}")" 2>/dev/null || true
    printf '%s\n' "${ts} [${level}] ${msg}" >>"${KIRO_LOG_FILE}" || true
  fi
}

_log_enabled() {
  local want; want=$(_log_level_to_num "${KIRO_LOG_LEVEL}")
  local have; have=$(_log_level_to_num "$1")
  [[ ${have} -ge ${want} ]]
}

log_trace() { _log_enabled TRACE && _log_emit TRACE "$*" || true; }
log_debug() { _log_enabled DEBUG && _log_emit DEBUG "$*" || true; }
log_info()  { _log_enabled INFO  && _log_emit INFO  "$*" || true; }
log_warn()  { _log_enabled WARN  && _log_emit WARN  "$*" || true; }
log_error() { _log_emit ERROR "$*"; }

