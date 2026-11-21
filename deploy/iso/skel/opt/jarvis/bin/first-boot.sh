#!/usr/bin/env bash
# Idempotent first-boot: persona, model, CoWork provider. Approval engine stays on.
set -euo pipefail
FLAG=/var/lib/jarvis/first-boot-done
LOG=/var/log/jarvis-first-boot.log
mkdir -p /var/lib/jarvis /home/user/jarvis-workspace /opt/jarvis/models
exec >>"$LOG" 2>&1
echo "==== Jarvis first-boot $(date -Is) ===="

# Wait a bit for the network if we still need to fetch the model.
if [[ ! -f /opt/jarvis/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf ]]; then
  for i in $(seq 1 30); do
    if curl -fsS https://huggingface.co >/dev/null 2>&1; then break; fi
    sleep 2
  done
fi
/opt/jarvis/bin/fetch-lfm3.sh

# Keep a copy visible to select_model.py (ROOT is the CoWork tree).
mkdir -p /opt/jarvis/cowork/models
ln -sfn /opt/jarvis/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf \
  /opt/jarvis/cowork/models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf
# Optional 8B, if the user dropped it onto the persistence volume.
if [[ -f /opt/jarvis/models/mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf ]]; then
  ln -sfn /opt/jarvis/models/mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf \
    /opt/jarvis/cowork/models/mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf
fi

# Jarvis persona into the live user's workspace kit.
if [[ -x /opt/jarvis/cowork/scripts/install-jarvis-persona.sh ]]; then
  /opt/jarvis/cowork/scripts/install-jarvis-persona.sh /home/user/jarvis-workspace/.cowork
fi
chown -R user:user /home/user/jarvis-workspace 2>/dev/null || true

# Point CoWork at local llama-server. Do not relax approval.
export PATH="/opt/jarvis/node/bin:/opt/jarvis/bin:${PATH}"
# The llama unit starts after this oneshot, so provider configure is retried by start-cowork.sh.
touch "$FLAG"
echo "first-boot complete"
