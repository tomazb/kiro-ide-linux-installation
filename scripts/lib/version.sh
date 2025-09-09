#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Version helpers: read installed and remote versions, compare

kiro_version_sort_ge() {
  # returns 0 if $1 >= $2 using sort -V
  printf '%s\n%s\n' "$1" "$2" | sort -V -C 2>/dev/null && return 0 || return 1
}

