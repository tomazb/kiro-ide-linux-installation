#!/usr/bin/env bash
# Run the local Kiro container image with X11 or Wayland integration.
# This does not distribute any binaries; it runs your locally built image.
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run-container.sh [--engine podman|docker] [--image NAME] [--tag TAG] [--backend x11|wayland] [--gpu] [--] [CMD...]

Options:
  --engine     Container engine (default: podman if available, otherwise docker)
  --image      Image name (default: kiro-runtime)
  --tag        Image tag (default: latest)
  --backend    Display backend: x11 (default) or wayland
  --gpu        Add GPU device (/dev/dri) to the container
  --           Pass all remaining args as the container command (default: kiro)

Examples:
  # X11 (default backend)
  xhost +local:
  scripts/run-container.sh

  # Wayland
  scripts/run-container.sh --backend wayland

  # With docker and custom image name/tag
  scripts/run-container.sh --engine docker --image my/kiro --tag dev

Notes:
  - For X11, ensure DISPLAY is set and you may need: xhost +local:
  - For Wayland, ensure WAYLAND_DISPLAY and XDG_RUNTIME_DIR are set on the host.
  - Use -- to pass alternate commands, e.g., "-- bash" to open a shell.
EOF
}

ENGINE=""
IMAGE_NAME="kiro-runtime"
IMAGE_TAG="latest"
BACKEND="x11"
USE_GPU=false
CMD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine) ENGINE="$2"; shift 2;;
    --image) IMAGE_NAME="$2"; shift 2;;
    --tag) IMAGE_TAG="$2"; shift 2;;
    --backend) BACKEND="$2"; shift 2;;
    --gpu) USE_GPU=true; shift;;
    -h|--help) usage; exit 0;;
    --) shift; CMD_ARGS=("$@"); break;;
    *) echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$ENGINE" ]]; then
  if command -v podman >/dev/null 2>&1; then ENGINE=podman; elif command -v docker >/dev/null 2>&1; then ENGINE=docker; else echo "Neither podman nor docker found" >&2; exit 1; fi
fi

if [[ "${BACKEND}" != "x11" && "${BACKEND}" != "wayland" ]]; then
  echo "Unsupported backend: ${BACKEND}. Use x11 or wayland." >&2
  exit 2
fi

RUN_ARGS=("${ENGINE}" run --rm)

# GPU device if requested
if [[ "${USE_GPU}" == true ]]; then
  RUN_ARGS+=(--device /dev/dri)
fi

case "${BACKEND}" in
  x11)
    # X11 integration
    : "${DISPLAY:?DISPLAY is not set. For X11, set DISPLAY and consider \"xhost +local:\"}"
    RUN_ARGS+=(
      -e DISPLAY
      -v /tmp/.X11-unix:/tmp/.X11-unix:ro
    )
    ;;
  wayland)
    : "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set for Wayland backend}"
    : "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set for Wayland backend}"
    RUN_ARGS+=(
      -e WAYLAND_DISPLAY
      -e XDG_RUNTIME_DIR
      -v "${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}"
    )
    ;;
esac

# Image
RUN_ARGS+=("${IMAGE_NAME}:${IMAGE_TAG}")

# Default command runs kiro
if [[ ${#CMD_ARGS[@]} -eq 0 ]]; then
  CMD_ARGS=(kiro)
fi

printf 'Running: %q ' "${RUN_ARGS[@]}"; printf '%q ' "${CMD_ARGS[@]}"; echo
exec "${RUN_ARGS[@]}" "${CMD_ARGS[@]}"

