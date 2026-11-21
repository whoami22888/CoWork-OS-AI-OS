#!/usr/bin/env bash
# Start llama-server with the tier selected for this host.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${MODEL_CONFIG:-$ROOT/config/models.json}"
SELECTION="$(python3 "$ROOT/scripts/select_model.py" --config "$CONFIG")"
echo "$SELECTION" >&2

MODEL="$(python3 -c "import json,sys; print(json.load(sys.stdin)['model_path'] or '')" <<<"$SELECTION")"
ALIAS="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('alias') or 'local')" <<<"$SELECTION")"
CTX="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('ctx_size') or 8192)" <<<"$SELECTION")"
HOST="${LLAMA_HOST:-127.0.0.1}"
PORT="${LLAMA_PORT:-8080}"
BIN_DIR="${LLAMA_BIN_DIR:-$ROOT/tools/llama.cpp/llama-b12600}"

if [[ -z "$MODEL" || ! -f "$MODEL" ]]; then
  echo "Selected model file is missing: ${MODEL:-none}" >&2
  exit 1
fi
if [[ ! -x "$BIN_DIR/llama-server" ]]; then
  echo "llama-server not found at $BIN_DIR" >&2
  exit 1
fi

export LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}"
exec "$BIN_DIR/llama-server" \
  -m "$MODEL" \
  --host "$HOST" \
  --port "$PORT" \
  --alias "$ALIAS" \
  --ctx-size "${LLAMA_CTX:-$CTX}" \
  --parallel 1
