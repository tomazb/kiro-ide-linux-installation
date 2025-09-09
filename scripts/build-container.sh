#!/usr/bin/env bash
# Build a local container image with the Kiro installer fetching binaries during build.
# No images are published by this repository; this is for local use only.
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-container.sh [--engine podman|docker] [--image NAME] [--tag TAG] [--no-cache]

Options:
  --engine     Container engine to use (default: podman if available, otherwise docker)
  --image      Image name (default: kiro-runtime)
  --tag        Image tag (default: latest)
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)
      ENGINE="$2"; shift 2;;
    --image)
      IMAGE_NAME="$2"; shift 2;;
    --tag)
      IMAGE_TAG="$2"; shift 2;;
    --no-cache)
      NO_CACHE="--no-cache"; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$ENGINE" ]]; then
  if command -v podman >/dev/null 2>&1; then ENGINE=podman; elif command -v docker >/dev/null 2>&1; then ENGINE=docker; else echo "Neither podman nor docker found" >&2; exit 1; fi
fi

CMD=("$ENGINE" build -t "$IMAGE_NAME:$IMAGE_TAG" -f Containerfile .)
if [[ -n "$NO_CACHE" ]]; then CMD+=("--no-cache"); fi

printf 'Building image: %s\n' "$IMAGE_NAME:$IMAGE_TAG"
"${CMD[@]}"

echo "Done. To run (X11 example):"
echo "  xhost +local:"
echo "  $ENGINE run --rm -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --device /dev/dri $IMAGE_NAME:$IMAGE_TAG kiro"

