#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE="code.homelab.media:5115/nimda/kodi-builder"
REBUILD_IMAGE=false
TARGET=""

usage() {
  echo "Usage: $0 [--rebuild] [kodi|addons|all]"
  echo "  kodi      - build kodi-gbm-git package"
  echo "  addons    - build kodi-gbm-addons-git package"
  echo "  all       - build both (default)"
  echo "  --rebuild - force rebuild of the docker image"
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --rebuild) REBUILD_IMAGE=true ;;
    kodi|addons|all) TARGET="$arg" ;;
    *) usage ;;
  esac
done

TARGET="${TARGET:-all}"

run_build() {
  podman run --rm --userns=keep-id --network=host \
    -v "$SCRIPT_DIR:/build/kodi-piers-gbm-git" \
    -v kodi-src-cache:/home/builder/.cache \
    -v kodi-ccache:/home/builder/.ccache \
    -e CCACHE_DIR=/home/builder/.ccache \
    "$IMAGE" -c "$1"
}

cleanup_old_packages() {
  local pattern=$1
  ls -1t $pattern 2>/dev/null | tail -n +6 | xargs -r rm -f
}

build_kodi() {
  local pkg_pattern="$SCRIPT_DIR/kodi/kodi-gbm-git-*.pkg.tar.zst"
  local before_count=$(ls -1 $pkg_pattern 2>/dev/null | wc -l)

  echo "==> Building kodi..."
  run_build '
    cd /build/kodi-piers-gbm-git/kodi
    makepkg -sf --noconfirm --skippgpcheck 2>&1 | tee build.log
  '

  local after_count=$(ls -1 $pkg_pattern 2>/dev/null | wc -l)
  if [ "$after_count" -gt "$before_count" ]; then
    cleanup_old_packages "$pkg_pattern"
    echo "==> Done: $(ls -1t $pkg_pattern | head -1)"
  else
    echo "No new package produced — check kodi/build.log"
  fi
}

build_addons() {
  local pkg_pattern="$SCRIPT_DIR/addons/kodi-gbm-addons-git-*.pkg.tar.zst"
  local before_count=$(ls -1 $pkg_pattern 2>/dev/null | wc -l)

  echo "==> Building addons..."
  run_build '
    cd /build/kodi-piers-gbm-git/addons
    makepkg -f --nodeps --noconfirm --skippgpcheck 2>&1 | tee build.log
  '

  local after_count=$(ls -1 $pkg_pattern 2>/dev/null | wc -l)
  if [ "$after_count" -gt "$before_count" ]; then
    cleanup_old_packages "$pkg_pattern"
    echo "==> Done: $(ls -1t $pkg_pattern | head -1)"
  else
    echo "No new package produced — check addons/build.log"
  fi
}

if $REBUILD_IMAGE || ! podman image exists "$IMAGE"; then
  echo "==> Building docker image..."
  podman build -t "$IMAGE" "$SCRIPT_DIR/docker"
else
  echo "==> Using existing docker image (use --rebuild to update)"
fi

case "$TARGET" in
  kodi)   build_kodi ;;
  addons) build_addons ;;
  all)    build_kodi; build_addons ;;
esac
