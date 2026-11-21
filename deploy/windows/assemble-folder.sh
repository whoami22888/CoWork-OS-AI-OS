#!/usr/bin/env bash
# Stage deploy/windows/dist/JarvisPortable from this Linux (or Git Bash) host.
# Does not build the Electron NSIS installer (that requires Windows).
set -euo pipefail
WIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${WIN_DIR}/../.." && pwd)"
DIST="${WIN_DIR}/dist/JarvisPortable"
rm -rf "${DIST}"
mkdir -p "${DIST}/bin/llama" "${DIST}/bin/node" "${DIST}/models" "${DIST}/cowork" \
  "${DIST}/scripts" "${DIST}/workspace/.cowork"
cp -a "${WIN_DIR}/layout/Jarvis.bat" "${WIN_DIR}/layout/Jarvis.ps1" "${DIST}/"
cp -a "${WIN_DIR}/README.md" "${DIST}/README.md"
cp -a "${WIN_DIR}/scripts/"*.ps1 "${DIST}/scripts/"
cp -a "${ROOT}/scripts/select_model.py" "${ROOT}/scripts/profile_host.py" "${DIST}/scripts/"
mkdir -p "${DIST}/config"
cp -a "${ROOT}/config/models.json" "${DIST}/config/"
# select_model.py expects repo root = parent of scripts/, so also put models.json
# where a cowork checkout would.
mkdir -p "${DIST}/cowork/config" "${DIST}/cowork/scripts" "${DIST}/cowork/resources"
cp -a "${ROOT}/config/models.json" "${DIST}/cowork/config/"
cp -a "${ROOT}/scripts/select_model.py" "${ROOT}/scripts/profile_host.py" "${DIST}/cowork/scripts/"
cp -a "${ROOT}/resources/jarvis-persona" "${DIST}/cowork/resources/"
cp -a "${ROOT}/resources/jarvis-persona/"*.md "${DIST}/workspace/.cowork/"
# A pointer rather than the whole repo (which is huge). Operators copy/clone CoWork into cowork/.
cat > "${DIST}/cowork/PUT-COWORK-HERE.txt" << 'TXT'
Copy or clone the CoWork-OS-AI-OS tree into this folder (so bin/cowork-cli.js
exists here), then run npm ci with Node >= 24. See the portable README.
TXT
# Never copy the 8B. Optionally copy LFM3 when INCLUDE_LFM3=1.
if [[ "${INCLUDE_LFM3:-0}" == "1" && -f "${ROOT}/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf" ]]; then
  cp -a "${ROOT}/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf" "${DIST}/models/"
  echo "Staged LFM3 into ${DIST}/models"
fi
cat > "${DIST}/models/README.txt" << 'TXT'
Place LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf here, or run scripts\fetch-lfm3.ps1.
Optional 8B: mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf (not downloaded by default).
TXT
echo "Staged ${DIST}"
find "${DIST}" -maxdepth 3 -type f | sort
