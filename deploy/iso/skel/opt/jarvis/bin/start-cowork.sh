#!/usr/bin/env bash
# Headless CoWork daemon, pointed at local llama-server. Approval engine stays on.
set -euo pipefail
export PATH="/opt/jarvis/node/bin:/opt/jarvis/bin:${PATH}"
export LLAMA_BASE_URL="${LLAMA_BASE_URL:-http://127.0.0.1:8080/v1}"
export COWORK_APPROVAL_PROMPTS="${COWORK_APPROVAL_PROMPTS:-on}"
COWORK=/opt/jarvis/cowork
NODE=/opt/jarvis/node/bin/node

# Wait for llama-server.
i=0
while [ "$i" -lt 90 ]; do
  if curl -fsS http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then break; fi
  i=$((i + 1))
  sleep 2
done

ALIAS=$(jq -r '.alias // "LFM3-1.7B-Uncensored"' /run/jarvis/selection.json 2>/dev/null || echo LFM3-1.7B-Uncensored)
cd "$COWORK"
"$NODE" "$COWORK/bin/cowork-cli.js" providers configure openai-compatible \
  --api-key local \
  --model "$ALIAS" \
  --base-url "$LLAMA_BASE_URL" || true

# Node-only daemon if present; otherwise stay idle (CLI still works via jarvis-chat).
if [[ -f "$COWORK/bin/coworkd-node.js" ]]; then
  exec "$NODE" "$COWORK/bin/coworkd-node.js"
fi
# Keep the unit alive so a restart still re-configures the provider.
exec sleep infinity
