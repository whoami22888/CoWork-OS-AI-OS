#!/usr/bin/env bash
# Start llama-server with the tier selected by profile_host + select_model.
set -euo pipefail
export PATH="/opt/jarvis/llama:/opt/jarvis/node/bin:/opt/jarvis/bin:${PATH}"
export LD_LIBRARY_PATH="/opt/jarvis/llama:${LD_LIBRARY_PATH:-}"
COWORK="${JARVIS_COWORK:-/opt/jarvis/cowork}"
mkdir -p /run/jarvis /opt/jarvis/models /opt/jarvis/cowork/models
ln -sfn /opt/jarvis/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf \
  /opt/jarvis/cowork/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf 2>/dev/null || true
if [[ -f /opt/jarvis/models/mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf ]]; then
  ln -sfn /opt/jarvis/models/mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf \
    /opt/jarvis/cowork/models/mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf
fi

SEL=/run/jarvis/selection.json
python3 "$COWORK/scripts/select_model.py" > "$SEL"
MODEL=$(jq -r '.model_path' "$SEL")
CTX=$(jq -r '.ctx_size' "$SEL")
ALIAS=$(jq -r '.alias' "$SEL")
echo "Selected $(jq -c . "$SEL")"
if [[ ! -f "$MODEL" ]]; then
  echo "Selected model is missing: $MODEL" >&2
  exit 1
fi
exec llama-server \
  -m "$MODEL" \
  --host 127.0.0.1 \
  --port 8080 \
  --alias "$ALIAS" \
  --ctx-size "${CTX:-32768}" \
  --parallel 1
