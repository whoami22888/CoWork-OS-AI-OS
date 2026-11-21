#!/bin/sh
# Point CoWork at the local llama-server, then run the image command.
# Does not relax the approval/permission engine.
set -eu
LLAMA_BASE_URL="${LLAMA_BASE_URL:-http://llama:8080/v1}"
JARVIS_MODEL_ALIAS="${JARVIS_MODEL_ALIAS:-Qwen3-8B-abliterated}"

i=0
while [ "$i" -lt 60 ]; do
  if curl -fsS "${LLAMA_BASE_URL%/v1}/v1/models" >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 2
done

if command -v node >/dev/null 2>&1 && [ -f /app/bin/cowork-cli.js ]; then
  node /app/bin/cowork-cli.js providers configure openai-compatible \
    --api-key local \
    --model "$JARVIS_MODEL_ALIAS" \
    --base-url "$LLAMA_BASE_URL" || true
fi

exec "$@"
