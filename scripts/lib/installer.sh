#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
IFS=$'\n\t'

# Installer library implementing install and uninstall flows
# Requires: log.sh, config.sh, cli.sh, os.sh, sudo.sh, deps.sh, fs.sh, net.sh, version.sh, state.sh

kiro_fetch_metadata() {
  local tmpdir="$1"
  local url="${KIRO_METADATA_URL}"
  local outfile="${tmpdir}/metadata.json"

  log_info "Fetching metadata: ${url}"
  if ! kiro_net_download "${url}" "${outfile}" 5; then
    log_error "Failed to download metadata from ${url}"
    return 1
  fi

  if [[ ! -s "${outfile}" ]]; then
    log_error "Metadata file is empty: ${outfile}"
    return 1
  fi

  KIRO_CURRENT_VERSION=$(jq -r '.currentRelease // empty' "${outfile}")
  if [[ -z "${KIRO_CURRENT_VERSION}" || "${KIRO_CURRENT_VERSION}" == "null" ]]; then
    log_error "Could not determine current version from metadata"
    return 1
  fi

  # Find a tar.gz package URL
  KIRO_PACKAGE_URL=$(jq -r '.releases[] | select(.updateTo.url | endswith(".tar.gz")) | .updateTo.url' "${outfile}" | head -n1)
  if [[ -z "${KIRO_PACKAGE_URL}" || "${KIRO_PACKAGE_URL}" == "null" ]]; then
    log_error "Could not find a .tar.gz package URL in metadata"
    return 1
  fi

  log_info "Latest version: ${KIRO_CURRENT_VERSION}"
  log_debug "Package URL: ${KIRO_PACKAGE_URL}"

  KIRO_METADATA_FILE="${outfile}"
}

kiro_get_installed_version() {
  local install_dir="$1"
  local v=""

  if [[ -x "${install_dir}/bin/kiro" ]]; then
    v=$("${install_dir}/bin/kiro" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
    if [[ -z "${v}" ]]; then
      v=$("${install_dir}/bin/kiro" -v 2>/dev/null | head -n1 | tr -d ' \n\r' || true)
    fi
  fi
  if [[ -z "${v}" && -x "${install_dir}/kiro" ]]; then
    v=$("${install_dir}/kiro" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
  fi

  # Fallback: check state file
  if [[ -z "${v}" ]]; then
    local st; st=$(kiro_state_file)
    if [[ -f "${st}" ]]; then
      v=$(jq -r '.version // empty' "${st}" 2>/dev/null || true)
    fi
  fi
  printf '%s\n' "${v}"
}

kiro_check_update_needed() {
  local install_dir="$1"; shift
  local force="${1:-false}"

  if [[ "${force}" == true ]]; then
    log_warn "Force install requested; skipping version check"
    return 0
  fi

  local installed; installed=$(kiro_get_installed_version "${install_dir}" || true)
  if [[ -z "${installed}" ]]; then
    log_info "No existing installation; a fresh install will be performed"
    return 0
  fi
  log_info "Currently installed: ${installed}"

  if kiro_version_sort_ge "${installed}" "${KIRO_CURRENT_VERSION}"; then
    if [[ "${installed}" == "${KIRO_CURRENT_VERSION}" ]]; then
      log_info "Already up to date (version ${installed})"
    else
      log_info "Installed version (${installed}) is newer than available (${KIRO_CURRENT_VERSION}); skipping"
    fi
    return 1
  else
    log_info "Update available: ${installed} -> ${KIRO_CURRENT_VERSION}"
    return 0
  fi
}

kiro_download_and_extract() {
  local tmpdir="$1"
  local extract_dir="${tmpdir}/extracted"
  mkdir -p "${extract_dir}"

  # If a local or explicit package is provided, use it (supports file:, http(s) URLs, or local paths)
  if [[ -n "${KIRO_PACKAGE_LOCAL:-}" ]]; then
    local archive=""
    local source_url=""
    if [[ "${KIRO_PACKAGE_LOCAL}" =~ ^file:(.+)$ ]]; then
      archive="${BASH_REMATCH[1]}"
      source_url="${KIRO_PACKAGE_LOCAL}"
    elif [[ -f "${KIRO_PACKAGE_LOCAL}" ]]; then
      archive="${KIRO_PACKAGE_LOCAL}"
      source_url="file:${KIRO_PACKAGE_LOCAL}"
    else
      # Treat as URL
      local out="${tmpdir}/kiro.tar.gz"
      log_info "Downloading package from explicit source: ${KIRO_PACKAGE_LOCAL}"
      kiro_net_download "${KIRO_PACKAGE_LOCAL}" "${out}" 5
      archive="${out}"
      source_url="${KIRO_PACKAGE_LOCAL}"
    fi

    if ! kiro_verify_archive "${archive}" "${source_url}"; then
      return 1
    fi
    log_info "Extracting package..."
    tar -xzf "${archive}" -C "${extract_dir}"

    local payload="${extract_dir}"
    if [[ -d "${extract_dir}/Kiro" ]]; then
      payload="${extract_dir}/Kiro"
    else
      payload="${extract_dir}"
    fi

    if [[ ! -e "${payload}/bin/kiro" && ! -e "${payload}/kiro" ]]; then
      log_error "Extracted payload is missing kiro executable"
      find "${extract_dir}" -maxdepth 2 \( -type f -o -type d \) | sort | head -n 50 | sed 's/^/ > /'
      return 1
    fi

    KIRO_PAYLOAD_DIR="${payload}"
    return 0
  fi

  # Otherwise, fetch via metadata URL (default online flow)
  # Cache path per version
  local cache_dir="${KIRO_CACHE_DIR:-${HOME}/.cache/kiro}/releases/${KIRO_CURRENT_VERSION}"
  mkdir -p "${cache_dir}"
  local archive="${cache_dir}/kiro.tar.gz"

  if [[ -s "${archive}" ]]; then
    log_info "Using cached package: ${archive}"
  else
    log_info "Downloading package..."
    kiro_net_download "${KIRO_PACKAGE_URL}" "${archive}" 5
  fi

  # Verify integrity (warns if no checksum available unless --skip-verify)
  if ! kiro_verify_archive "${archive}" "${KIRO_PACKAGE_URL}"; then
    rm -f "${archive}" || true
    return 1
  fi

  log_info "Extracting package..."
  tar -xzf "${archive}" -C "${extract_dir}"

  # Normalize path; look for nested Kiro directory
  local payload="${extract_dir}"
  if [[ -d "${extract_dir}/Kiro" ]]; then
    payload="${extract_dir}/Kiro"
  else
    # Some builds might place files directly
    payload="${extract_dir}"
  fi

  if [[ ! -e "${payload}/bin/kiro" && ! -e "${payload}/kiro" ]]; then
    log_error "Extracted payload is missing kiro executable"
    find "${extract_dir}" -maxdepth 2 \( -type f -o -type d \) | sort | head -n 50 | sed 's/^/ > /'
    return 1
  fi

  KIRO_PAYLOAD_DIR="${payload}"
}

kiro_prepare_paths() {
  local user_only="$1"
  if [[ "${user_only}" == true ]]; then
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
}

kiro_set_permissions() {
  local pfx="$1"
  if [[ -x "${pfx}/kiro" ]]; then
    kiro_maybe_sudo chmod +x "${pfx}/kiro" || true
  fi
  if [[ -x "${pfx}/bin/kiro" ]]; then
    kiro_maybe_sudo chmod +x "${pfx}/bin/kiro" || true
  fi
  if [[ -e "${pfx}/chrome-sandbox" ]]; then
    kiro_maybe_sudo chmod 4755 "${pfx}/chrome-sandbox" || log_warn "Failed to set SUID on chrome-sandbox"
  fi
}

kiro_download_icon() {
  local target_dir="$1"
  local need_sudo_flag="$2"
  local icon_dir="${target_dir}/resources/app/resources/linux"
  local local_icon="${ROOT_DIR}/assets/Kiro_1024x1024x32.png"

  if [[ "${need_sudo_flag}" == true ]]; then
    kiro_maybe_sudo mkdir -p "${icon_dir}"
  else
    mkdir -p "${icon_dir}"
  fi

  if [[ -f "${local_icon}" ]]; then
    if [[ "${need_sudo_flag}" == true ]]; then
      kiro_maybe_sudo cp "${local_icon}" "${icon_dir}/kiro.png"
    else
      cp "${local_icon}" "${icon_dir}/kiro.png"
    fi
    log_info "Installed icon to ${icon_dir}/kiro.png"
    return 0
  fi

  local -a system_icons=(
    "/usr/share/icons/hicolor/128x128/apps/code.png"
    "/usr/share/icons/hicolor/128x128/apps/visual-studio-code.png"
    "/usr/share/icons/hicolor/128x128/apps/com.visualstudio.code.png"
    "/usr/share/icons/hicolor/scalable/apps/text-editor.svg"
    "/usr/share/icons/hicolor/128x128/apps/accessories-text-editor.png"
  )
  local icon
  for icon in "${system_icons[@]}"; do
    if [[ -f "${icon}" ]]; then
      if [[ "${need_sudo_flag}" == true ]]; then
        sudo cp "${icon}" "${icon_dir}/kiro.png"
      else
        cp "${icon}" "${icon_dir}/kiro.png"
      fi
      log_info "Using system icon: ${icon}"
      return 0
    fi
  done
  log_warn "No icon found; desktop entry will reference missing icon until provided"
}

kiro_create_desktop_entry() {
  local pfx="$1"; shift
  local desktop_dir="$1"; shift
  local need_sudo_flag="$1"; shift

  local icon_path
  if [[ -f "${pfx}/resources/app/resources/linux/kiro.png" ]]; then
    icon_path="${pfx}/resources/app/resources/linux/kiro.png"
  elif [[ -f "${pfx}/resources/app/resources/app.png" ]]; then
    icon_path="${pfx}/resources/app/resources/app.png"
  else
    kiro_download_icon "${pfx}" "${need_sudo_flag}" || true
    icon_path="${pfx}/resources/app/resources/linux/kiro.png"
  fi

  local desktop_content
  desktop_content=$(cat <<EOF
[Desktop Entry]
Name=Kiro
Comment=Kiro - AI-powered development environment
Exec=${pfx}/bin/kiro %F
Icon=${icon_path}
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=text/plain;inode/directory;
StartupWMClass=kiro
StartupNotify=true
EOF
)

  local desktop_file="${desktop_dir}/kiro.desktop"
  mkdir -p "${desktop_dir}"
  if [[ "${need_sudo_flag}" == true ]]; then
    printf '%s' "${desktop_content}" | kiro_maybe_sudo tee "${desktop_file}" >/dev/null
    kiro_maybe_sudo chmod +x "${desktop_file}"
  else
    kiro_fs_atomic_write "${desktop_file}" <<<"${desktop_content}"
    chmod +x "${desktop_file}"
  fi

  if command -v update-desktop-database >/dev/null 2>&1; then
    if [[ "${need_sudo_flag}" == true ]]; then
      kiro_maybe_sudo update-desktop-database "${desktop_dir}" || true
    else
      update-desktop-database "${desktop_dir}" || true
    fi
  fi
}

kiro_install_main() {
  local user_only="$1"
  local force_update="$2"

  kiro_prepare_paths "${user_only}"

  local tmp; tmp=$(kiro_fs_mktmpdir)
  trap "rm -rf '${tmp}'" RETURN

  # If explicit package is provided, skip metadata and update checks
  if [[ -z "${KIRO_PACKAGE_LOCAL:-}" ]]; then
    kiro_fetch_metadata "${tmp}"
    if ! kiro_check_update_needed "${INSTALL_PREFIX}" "${force_update}"; then
      return 0
    fi
  else
    log_info "Using explicit package via --package; skipping metadata and update checks"
  fi

  kiro_download_and_extract "${tmp}"

  log_info "Copying files to ${INSTALL_PREFIX}"
  if [[ "${NEED_SUDO}" == true ]]; then
    kiro_maybe_sudo mkdir -p "${INSTALL_PREFIX}"
    kiro_maybe_sudo cp -r "${KIRO_PAYLOAD_DIR}"/* "${INSTALL_PREFIX}"
  else
    mkdir -p "${INSTALL_PREFIX}"
    cp -r "${KIRO_PAYLOAD_DIR}"/* "${INSTALL_PREFIX}"
  fi

  kiro_set_permissions "${INSTALL_PREFIX}"

  # Symlink
  mkdir -p "${SYMLINK_DIR}"
  if [[ "${NEED_SUDO}" == true ]]; then
    kiro_maybe_sudo ln -sf "${INSTALL_PREFIX}/bin/kiro" "${SYMLINK_DIR}/kiro"
  else
    ln -sf "${INSTALL_PREFIX}/bin/kiro" "${SYMLINK_DIR}/kiro"
  fi

  # Desktop entry
  kiro_create_desktop_entry "${INSTALL_PREFIX}" "${DESKTOP_DIR}" "${NEED_SUDO}"

  # Write state
  local st_json
  # Compose state. In offline mode, KIRO_CURRENT_VERSION may be unset; fall back to KIRO_TARGET_VERSION or a sentinel.
  local version_for_state
  version_for_state="${KIRO_CURRENT_VERSION:-${KIRO_TARGET_VERSION:-(local-package)}}"
  local source_for_state
  source_for_state="${KIRO_PACKAGE_URL:-${KIRO_PACKAGE_LOCAL:-unknown}}"
  st_json=$(jq -n --arg version "${version_for_state}" --arg prefix "${INSTALL_PREFIX}" --arg url "${source_for_state}" --arg ts "$(date -u +%FT%TZ)" '{version:$version,prefix:$prefix,source:$url,installed_at:$ts}')
  kiro_state_write "${st_json}"

  log_info "Installation complete: version ${version_for_state}"
}

kiro_uninstall_main() {
  local user_only="$1"
  local clean="$2"

  kiro_prepare_paths "${user_only}"

  if [[ ! -d "${INSTALL_PREFIX}" ]]; then
    log_warn "Kiro not found at ${INSTALL_PREFIX}"
  else
    log_info "Removing ${INSTALL_PREFIX}"
    if [[ "${NEED_SUDO}" == true ]]; then
      kiro_maybe_sudo rm -rf "${INSTALL_PREFIX}"
    else
      rm -rf "${INSTALL_PREFIX}"
    fi
  fi

  # Symlink
  if [[ -L "${SYMLINK_DIR}/kiro" ]]; then
    log_info "Removing symlink ${SYMLINK_DIR}/kiro"
    if [[ "${NEED_SUDO}" == true ]]; then kiro_maybe_sudo rm -f "${SYMLINK_DIR}/kiro"; else rm -f "${SYMLINK_DIR}/kiro"; fi
  fi

  # Desktop entry
  if [[ -f "${DESKTOP_DIR}/kiro.desktop" ]]; then
    log_info "Removing desktop entry ${DESKTOP_DIR}/kiro.desktop"
    if [[ "${NEED_SUDO}" == true ]]; then kiro_maybe_sudo rm -f "${DESKTOP_DIR}/kiro.desktop"; else rm -f "${DESKTOP_DIR}/kiro.desktop"; fi
    if command -v update-desktop-database >/dev/null 2>&1; then
      if [[ "${NEED_SUDO}" == true ]]; then kiro_maybe_sudo update-desktop-database "${DESKTOP_DIR}" || true; else update-desktop-database "${DESKTOP_DIR}" || true; fi
    fi
  fi

  if [[ "${clean}" == true ]]; then
    log_info "Cleaning user configuration and caches"
    local -a dirs=(
      "$HOME/.config/kiro"
      "$HOME/.kiro"
      "$HOME/.local/state/kiro"
      "$HOME/.local/share/kiro-extensions"
      "$HOME/.cache/kiro"
      "$HOME/.vscode-kiro"
    )
    local d
    for d in "${dirs[@]}"; do
      [[ -d "${d}" ]] && rm -rf "${d}" || true
    done
  else
    log_info "User configuration preserved (use --clean to remove)"
  fi

  # Clear state (optional)
  local st; st=$(kiro_state_file)
  if [[ -f "${st}" ]]; then
    rm -f "${st}" || true
  fi

  log_info "Uninstall complete"
}

