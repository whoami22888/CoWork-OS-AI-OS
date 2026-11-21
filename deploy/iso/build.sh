#!/usr/bin/env bash
# One-command Debian live ISO build for Jarvis_liquid_agent.
# Usage (from anywhere):
#   ./deploy/iso/build.sh
# Optional: INCLUDE_LFM3=0 ./deploy/iso/build.sh    # fetch the 1.13 GiB model on first boot
#           INCLUDE_LFM3=1 ./deploy/iso/build.sh    # bake LFM3 into the ISO
set -euo pipefail
ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${ISO_DIR}/../.." && pwd)"
BUILD="${ISO_DIR}/.build"
DIST="${ISO_DIR}/dist"
OUT_NAME="jarvis-live-amd64.iso"

need=(lb xorriso mksquashfs debootstrap rsync curl python3 cpio)
missing=()
for t in "${need[@]}"; do
  command -v "$t" >/dev/null 2>&1 || missing+=("$t")
done
if ((${#missing[@]})); then
  cat >&2 <<HINT
Missing build tools: ${missing[*]}

On Debian/Ubuntu:
  sudo apt-get update
  sudo apt-get install -y live-build xorriso squashfs-tools debootstrap isolinux \\
    syslinux-common grub-pc-bin grub-efi-amd64-bin cpio rsync curl python3 ca-certificates
HINT
  exit 1
fi
if ! sudo -n true 2>/dev/null; then
  echo "sudo is required for \`lb build\` (debootstrap/chroot). Re-run with a working sudo." >&2
  exit 1
fi
if [[ ! -x "${ROOT}/tools/llama.cpp/llama-b12600/llama-server" ]]; then
  echo "Need a linux-x64 llama.cpp build at tools/llama.cpp/llama-b12600/llama-server (b12600+ with lfm3)." >&2
  exit 1
fi

"${ISO_DIR}/prepare_payload.sh"

mkdir -p "${DIST}"
cd "${BUILD}"
sudo lb clean --purge || true
# auto/config is run by `lb config`
lb config
sudo lb build

ISO=""
for candidate in \
  "${BUILD}/live-image-amd64.hybrid.iso" \
  "${BUILD}/live-image-amd64.iso" \
  "${BUILD}/binary.hybrid.iso"
do
  if [[ -f "$candidate" ]]; then ISO="$candidate"; break; fi
done
if [[ -z "$ISO" ]]; then
  echo "live-build finished but no hybrid ISO was found in ${BUILD}" >&2
  ls -la "${BUILD}" | head >&2 || true
  exit 1
fi

cp -f "$ISO" "${DIST}/${OUT_NAME}"
sha256sum "${DIST}/${OUT_NAME}" | tee "${DIST}/${OUT_NAME}.sha256"
# Convenience copy at the workspace root when we are on the dev box.
if [[ -d /workspace ]]; then
  cp -f "${DIST}/${OUT_NAME}" "/workspace/${OUT_NAME}"
  cp -f "${DIST}/${OUT_NAME}.sha256" "/workspace/${OUT_NAME}.sha256"
  echo "Also copied to /workspace/${OUT_NAME}"
fi
stat -c '%n %s bytes' "${DIST}/${OUT_NAME}"
echo "Done."
