#!/usr/bin/env bash
# Download the tiny-tier LFM3 GGUF if it is not already on disk.
set -euo pipefail
MODELS="${JARVIS_MODELS_DIR:-/opt/jarvis/models}"
FILE="LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf"
DEST="$MODELS/$FILE"
EXPECTED_BYTES="${JARVIS_MODEL_BYTES:-1132208000}"
EXPECTED_SHA256="${JARVIS_MODEL_SHA256:-b22df65673b54ed326f18f74826d76f3b65dadc237ffd6306cd52be04544827d}"
HF_URL="${JARVIS_HF_URL:-https://huggingface.co/AtomicChat/LFM3-1.7B-Uncensored-GGUF/resolve/main/${FILE}}"

mkdir -p "$MODELS"
if [[ -f "$DEST" ]]; then
  size=$(wc -c < "$DEST" | tr -d ' ')
  if [[ "$size" == "$EXPECTED_BYTES" ]]; then
    sha=$(sha256sum "$DEST" | awk '{print $1}')
    if [[ "$sha" == "$EXPECTED_SHA256" ]]; then
      echo "LFM3 already present and verified: $DEST"
      exit 0
    fi
  fi
  echo "Existing file failed size/hash check; re-downloading." >&2
  rm -f "$DEST"
fi

echo "Downloading LFM3 (1.13 GiB) from Hugging Face…"
curl -fL --retry 3 -C - -o "$DEST.partial" "$HF_URL"
mv "$DEST.partial" "$DEST"
size=$(wc -c < "$DEST" | tr -d ' ')
sha=$(sha256sum "$DEST" | awk '{print $1}')
if [[ "$size" != "$EXPECTED_BYTES" || "$sha" != "$EXPECTED_SHA256" ]]; then
  echo "Download failed verification: size=$size sha256=$sha" >&2
  exit 1
fi
echo "LFM3 ready: $DEST"
