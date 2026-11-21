#!/usr/bin/env bash
# Start llama-server (OpenAI-compatible /v1) with the local LFM3 GGUF.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="${LFM3_MODEL:-$ROOT/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf}"
HOST="${LLAMA_HOST:-127.0.0.1}"
PORT="${LLAMA_PORT:-8080}"
BIN_DIR="${LLAMA_BIN_DIR:-$ROOT/tools/llama.cpp/llama-b12600}"

if [[ ! -x "$BIN_DIR/llama-server" ]]; then
  echo "llama-server not found at $BIN_DIR." >&2
  echo "Download ggml-org/llama.cpp release b12600 (or newer) Ubuntu x64 build into tools/llama.cpp/" >&2
  exit 1
fi
if [[ ! -f "$MODEL" ]]; then
  echo "Model not found: $MODEL" >&2
  echo "Place LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf in models/ (gitignored)." >&2
  exit 1
fi

export LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}"
exec "$BIN_DIR/llama-server" \
  -m "$MODEL" \
  --host "$HOST" \
  --port "$PORT" \
  --alias LFM3-1.7B-Uncensored \
  --ctx-size "${LLAMA_CTX:-4096}" \
  --parallel 1
