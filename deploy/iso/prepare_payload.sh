#!/usr/bin/env bash
# Assemble the live-build tree under deploy/iso/.build (gitignored).
set -euo pipefail
ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${ISO_DIR}/../.." && pwd)"
BUILD="${ISO_DIR}/.build"
CACHE="${ISO_DIR}/.cache"
INCLUDE="${BUILD}/config/includes.chroot"
NODE_VER="${JARVIS_NODE_VERSION:-v24.22.1}"
NODE_TARBALL="node-${NODE_VER}-linux-x64.tar.xz"
INCLUDE_LFM3="${INCLUDE_LFM3:-auto}"

for tool in rsync curl python3; do
  command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 1; }
done

rm -rf "${BUILD}"
mkdir -p "${BUILD}/config" "${CACHE}" "${INCLUDE}"

# live-build scaffolding
cp -a "${ISO_DIR}/live-config/." "${BUILD}/"
chmod +x "${BUILD}/auto/config" "${BUILD}/config/hooks/normal/"*.hook.chroot 2>/dev/null || true

# Isolinux template fix (Debian stores modules in paths older templates get wrong).
if [[ -d /usr/share/live/build/bootloaders/isolinux ]]; then
  BOOT_TEMPLATE_DIR="${BUILD}/config/bootloaders/isolinux"
  mkdir -p "$(dirname "${BOOT_TEMPLATE_DIR}")"
  rm -rf "${BOOT_TEMPLATE_DIR}"
  cp -a /usr/share/live/build/bootloaders/isolinux "${BOOT_TEMPLATE_DIR}"
  ln -sfn /usr/lib/ISOLINUX/isolinux.bin "${BOOT_TEMPLATE_DIR}/isolinux.bin"
  if [[ -e /usr/lib/syslinux/modules/bios/vesamenu.c32 ]]; then
    ln -sfn /usr/lib/syslinux/modules/bios/vesamenu.c32 "${BOOT_TEMPLATE_DIR}/vesamenu.c32"
  fi
  mkdir -p "${BOOT_TEMPLATE_DIR}/.bootlogo"
  printf 'Jarvis Live\n' > "${BOOT_TEMPLATE_DIR}/.bootlogo/README"
  ( cd "${BOOT_TEMPLATE_DIR}/.bootlogo" && find . -print | cpio --quiet -o ) > "${BOOT_TEMPLATE_DIR}/bootlogo"
  rm -rf "${BOOT_TEMPLATE_DIR}/.bootlogo"
fi

# Static skel (units, launchers, first-boot scripts)
cp -a "${ISO_DIR}/skel/." "${INCLUDE}/"

# Node 24 official linux-x64 binary (CoWork requires >= 24; Debian bookworm is too old).
if [[ ! -f "${CACHE}/${NODE_TARBALL}" ]]; then
  echo "Downloading Node ${NODE_VER}…"
  curl -fL --retry 3 -o "${CACHE}/${NODE_TARBALL}" \
    "https://nodejs.org/dist/${NODE_VER}/${NODE_TARBALL}"
fi
mkdir -p "${INCLUDE}/opt/jarvis/node"
tar -xJf "${CACHE}/${NODE_TARBALL}" -C "${INCLUDE}/opt/jarvis/node" --strip-components=1

# llama.cpp Ubuntu x64 build already used in Phase 1 (arch lfm3, b12600).
LLAMA_SRC="${ROOT}/tools/llama.cpp/llama-b12600"
if [[ ! -x "${LLAMA_SRC}/llama-server" ]]; then
  echo "llama-server not found at ${LLAMA_SRC}." >&2
  echo "Place a linux-x64 llama.cpp build (b12600 or newer, with lfm3) there." >&2
  exit 1
fi
mkdir -p "${INCLUDE}/opt/jarvis/llama"
rsync -a --delete "${LLAMA_SRC}/" "${INCLUDE}/opt/jarvis/llama/"

# CoWork tree minus bulky / irrelevant paths. node_modules is included so the
# live session can run the CLI without an on-ISO npm install (Electron is dropped).
mkdir -p "${INCLUDE}/opt/jarvis/cowork"
rsync -a \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude 'models/*.gguf' \
  --exclude 'models/**/*.gguf' \
  --exclude 'proofs/' \
  --exclude 'deploy/iso/.build/' \
  --exclude 'deploy/iso/.cache/' \
  --exclude 'deploy/iso/dist/' \
  --exclude 'deploy/windows/.cache/' \
  --exclude 'deploy/windows/dist/' \
  --exclude 'release/' \
  --exclude '*.iso' \
  "${ROOT}/" "${INCLUDE}/opt/jarvis/cowork/"

if [[ -d "${ROOT}/node_modules" ]]; then
  echo "Copying node_modules (excluding Electron)…"
  rsync -a \
    --exclude 'electron/' \
    --exclude 'electron-builder/' \
    --exclude '@electron/' \
    --exclude 'app-builder-bin/' \
    --exclude '.cache/' \
    "${ROOT}/node_modules/" "${INCLUDE}/opt/jarvis/cowork/node_modules/"
else
  echo "WARNING: ${ROOT}/node_modules is missing; the ISO will not have a working CoWork CLI until you npm ci on the build host first." >&2
fi

# Models
mkdir -p "${INCLUDE}/opt/jarvis/models" "${INCLUDE}/opt/jarvis/cowork/models"
LFM3_SRC="${ROOT}/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf"
if [[ "${INCLUDE_LFM3}" == "auto" ]]; then
  if [[ -f "${LFM3_SRC}" ]]; then INCLUDE_LFM3=1; else INCLUDE_LFM3=0; fi
fi
if [[ "${INCLUDE_LFM3}" == "1" ]]; then
  if [[ ! -f "${LFM3_SRC}" ]]; then
    echo "INCLUDE_LFM3=1 but ${LFM3_SRC} is missing." >&2
    exit 1
  fi
  echo "Bundling LFM3 GGUF into the ISO (~1.13 GiB)…"
  cp -a "${LFM3_SRC}" "${INCLUDE}/opt/jarvis/models/"
else
  printf '%s\n' 'LFM3 is fetched on first boot by /opt/jarvis/bin/fetch-lfm3.sh' \
    > "${INCLUDE}/opt/jarvis/models/README.txt"
fi
# Never bundle the 8B into the ISO.
cat > "${INCLUDE}/opt/jarvis/models/ADD-8B.txt" << 'TXT'
To add the mid-size fallback (bartowski Qwen3-8B-abliterated Q4_K_M, ~5.03 GB):

  1. After boot (preferably with a persistence partition labelled like
     "persistence" so /opt/jarvis/models can be overlaid, or just copy onto
     the live user's home and move it):

       sudo mkdir -p /opt/jarvis/models
       sudo cp mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf /opt/jarvis/models/
       # expected: 5,027,784,288 bytes
       # sha256: 361557e69ad101ee22b1baf427283b7ddcf81bc7532b8cee8ac2c6b4d1b81ead
       # source: https://huggingface.co/bartowski/mlabonne_Qwen3-8B-abliterated-GGUF

  2. Reboot, or: sudo systemctl restart jarvis-llama.service

  On a capable host (enough RAM/VRAM per config/models.json) select_model.py
  will pick the 8B automatically once the file is present. Phone-class hosts
  stay on LFM3 unless JARVIS_ALLOW_MAIN=1 is set (not recommended).
TXT

# empty persistence-friendly workspace
mkdir -p "${INCLUDE}/etc/skel/jarvis-workspace"
# Make llama-server and node executable for the live user
chmod -R a+rX "${INCLUDE}/opt/jarvis" || true

# A tiny manifest for operators
{
  echo "prepared_at=$(date -Is)"
  echo "include_lfm3=${INCLUDE_LFM3}"
  echo "node=${NODE_VER}"
  echo "cowork_head=$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} > "${INCLUDE}/opt/jarvis/BUILDINFO"

echo "Payload ready at ${INCLUDE}"
du -sh "${INCLUDE}" "${INCLUDE}/opt/jarvis/models" "${INCLUDE}/opt/jarvis/cowork/node_modules" 2>/dev/null || true
