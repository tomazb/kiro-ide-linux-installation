#!/usr/bin/env bash
# Build a local container image with the Kiro installer fetching binaries during build.
# No images are published by this repository; this is for local use only.
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-container.sh [--engine podman|docker|nerdctl] [--image NAME] [--tag TAG] [--platform PLAT] [--no-cache]

Options:
  --engine     Container engine to use (default priority: $CONTAINER_ENGINE, then podman, docker, nerdctl)
  --image      Image name (default: kiro-runtime)
  --tag        Image tag (default: latest)
  --platform   Build platform (e.g., linux/amd64, linux/arm64). Auto-detected when possible.
  --no-cache   Build without cache

Examples:
  scripts/build-container.sh
  scripts/build-container.sh --engine docker --image my/kiro --tag dev --no-cache
EOF
}

ENGINE=""
IMAGE_NAME="kiro-runtime"
IMAGE_TAG="latest"
NO_CACHE=""
PLATFORM="${IMAGE_PLATFORM:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)
      ENGINE="$2"; shift 2;;
    --image)
      IMAGE_NAME="$2"; shift 2;;
    --tag)
      IMAGE_TAG="$2"; shift 2;;
    --platform)
      PLATFORM="$2"; shift 2;;
    --no-cache)
      NO_CACHE="--no-cache"; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

# Engine detection: honor explicit, then env, then common engines
if [[ -z "${ENGINE}" ]]; then
  if [[ -n "${CONTAINER_ENGINE:-}" ]] && command -v "${CONTAINER_ENGINE}" >/dev/null 2>&1; then
    ENGINE="${CONTAINER_ENGINE}"
  elif command -v podman >/dev/null 2>&1; then
    ENGINE=podman
  elif command -v docker >/dev/null 2>&1; then
    ENGINE=docker
  elif command -v nerdctl >/dev/null 2>&1; then
    ENGINE=nerdctl
  else
    echo "No container engine found (podman/docker/nerdctl)." >&2
    exit 1
  fi
fi

# Platform auto-detection (only if not provided)
if [[ -z "${PLATFORM}" ]]; then
  ARCH=$(uname -m || true)
  case "${ARCH}" in
    x86_64) PLATFORM="linux/amd64" ;;
    aarch64|arm64) PLATFORM="linux/arm64" ;;
    *) PLATFORM="" ;;
  esac
fi

# Build command selection and args
BUILD_CMD=("${ENGINE}" build)
if [[ "${ENGINE}" == docker ]]; then
  if docker buildx version >/dev/null 2>&1; then
    export DOCKER_BUILDKIT=1
    BUILD_CMD=(docker buildx build)
  fi
fi

# Assemble args
ARGS=( -t "${IMAGE_NAME}:${IMAGE_TAG}" -f Containerfile )
[[ -n "${NO_CACHE}" ]] && ARGS+=("${NO_CACHE}")
# Add platform for engines that support it
if [[ -n "${PLATFORM}" ]]; then
  case "${ENGINE}" in
    docker|nerdctl) ARGS+=(--platform "${PLATFORM}") ;;
    podman) : ;; # skip by default for broader compatibility
  esac
fi
ARGS+=( . )

# If using docker buildx, ensure the image is loaded into the local daemon
if [[ "${ENGINE}" == docker ]] && docker buildx version >/dev/null 2>&1; then
  [[ " ${ARGS[*]} " =~ " --load " ]] || ARGS+=(--load)
fi

printf 'Engine: %s\n' "${ENGINE}"
[[ -n "${PLATFORM}" ]] && printf 'Platform: %s\n' "${PLATFORM}" || true
printf 'Building image: %s\n' "${IMAGE_NAME}:${IMAGE_TAG}"
"${BUILD_CMD[@]}" "${ARGS[@]}"

echo "Done. To run (X11 example):"
echo "  xhost +local:"
echo "  $ENGINE run --rm -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --device /dev/dri $IMAGE_NAME:$IMAGE_TAG kiro"

