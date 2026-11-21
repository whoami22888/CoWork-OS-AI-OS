#!/bin/sh
# Install and start Jarvis llama-server (LFM3 tiny tier) inside a Linxr Alpine VM.
# Run as root from the Linxr Terminal tab, or via: ssh root@localhost -p 2222
#
#   sh setup-in-vm.sh
#   sh setup-in-vm.sh --download-model     # fetch the 1.13 GB GGUF from Hugging Face
#   sh setup-in-vm.sh --with-cowork        # also start CoWork (likely to OOM on an S23)
#   sh setup-in-vm.sh --backend ollama     # try Ollama on 11434 instead of llama.cpp
#
# Approvals stay ON if CoWork is started. The 8B model is not started by default.

set -eu

MODEL_DIR="${JARVIS_MODELS_DIR:-/mnt/sdcard/JarvisModels}"
MODEL_FILE="${JARVIS_MODEL_FILE:-LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf}"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
ALIAS="${JARVIS_MODEL_ALIAS:-LFM3-1.7B-Uncensored}"
CTX="${JARVIS_CTX:-8192}"
IMAGE="${JARVIS_LLAMA_IMAGE:-ghcr.io/ggml-org/llama.cpp:server}"
HF_REPO="${JARVIS_HF_REPO:-AtomicChat/LFM3-1.7B-Uncensored-GGUF}"
HF_FILE="${JARVIS_HF_FILE:-LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf}"
EXPECTED_BYTES="${JARVIS_MODEL_BYTES:-1132208000}"
EXPECTED_SHA256="${JARVIS_MODEL_SHA256:-b22df65673b54ed326f18f74826d76f3b65dadc237ffd6306cd52be04544827d}"
# Same public GGUF as the Drive file (id 196p8aUITT3WB1tY3AMivFz8jFz1a_LEu).
DOWNLOAD=0
WITH_COWORK=0
BACKEND=llama
COMPOSE_DIR=""

usage() {
  sed -n '2,12p' "$0"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --download-model) DOWNLOAD=1 ;;
    --with-cowork) WITH_COWORK=1 ;;
    --backend) BACKEND="$2"; shift ;;
    --compose-dir) COMPOSE_DIR="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_apk() {
  if ! need_cmd apk; then
    echo "not an Alpine VM? apk not found" >&2
    return 1
  fi
  apk add --no-cache docker docker-cli curl bash python3 ca-certificates
  # docker-compose plugin if packaged; fall back to the standalone binary later
  apk add --no-cache docker-cli-compose 2>/dev/null || apk add --no-cache docker-compose 2>/dev/null || true
}

ensure_docker() {
  if ! need_cmd docker; then
    ensure_apk
  fi
  if need_cmd rc-service; then
    rc-service docker start || true
  elif need_cmd service; then
    service docker start || true
  else
    dockerd >/var/log/dockerd.log 2>&1 &
    sleep 3
  fi
  i=0
  while [ "$i" -lt 30 ]; do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  echo "Docker daemon did not become ready. In Linxr, enable Docker on demand, then retry." >&2
  exit 1
}

arch_ok() {
  m=$(uname -m)
  case "$m" in
    aarch64|arm64) echo "host arch $m (arm64) — good" ;;
    *) echo "WARNING: host arch is $m, not arm64. This script targets Linxr on a phone." ;;
  esac
}


verify_model() {
  if [ ! -f "$MODEL_PATH" ]; then
    return 1
  fi
  bytes=$(wc -c < "$MODEL_PATH")
  if [ -n "$EXPECTED_BYTES" ] && [ "$bytes" -ne "$EXPECTED_BYTES" ]; then
    echo "WARNING: model size $bytes != expected $EXPECTED_BYTES" >&2
  fi
  if command -v sha256sum >/dev/null 2>&1 && [ -n "$EXPECTED_SHA256" ]; then
    got=$(sha256sum "$MODEL_PATH" | awk '{print $1}')
    if [ "$got" != "$EXPECTED_SHA256" ]; then
      echo "ERROR: SHA256 mismatch (got $got, expected $EXPECTED_SHA256)" >&2
      exit 1
    fi
    echo "SHA256 ok: $got"
  fi
}

place_model() {
  mkdir -p "$MODEL_DIR"
  if [ -f "$MODEL_PATH" ]; then
    echo "model present: $MODEL_PATH ($(wc -c < "$MODEL_PATH") bytes)"
    verify_model
    return 0
  fi
  if [ "$DOWNLOAD" -eq 1 ]; then
    echo "downloading $HF_FILE from Hugging Face into $MODEL_DIR ..."
    url="https://huggingface.co/${HF_REPO}/resolve/main/${HF_FILE}"
    curl -L --fail -o "$MODEL_PATH.partial" "$url"
    mv "$MODEL_PATH.partial" "$MODEL_PATH"
    echo "downloaded $(wc -c < "$MODEL_PATH") bytes"
    verify_model
    return 0
  fi
  cat >&2 <<MSG
GGUF not found at $MODEL_PATH

Copy it onto the phone first, then retry:

  Android path:  /storage/emulated/0/LinxrShare/JarvisModels/${MODEL_FILE}
  VM path:       ${MODEL_PATH}

Or re-run with --download-model (≈1.13 GB over Wi-Fi).
MSG
  exit 1
}

pull_llama_image() {
  echo "pulling $IMAGE for linux/arm64 ..."
  if ! docker pull --platform linux/arm64 "$IMAGE"; then
    echo "official image pull failed. See deploy/linxr/README.md for the source-build fallback." >&2
    exit 1
  fi
  arch=$(docker inspect "$IMAGE" --format '{{.Architecture}}' 2>/dev/null || echo unknown)
  echo "image architecture: $arch"
  if [ "$arch" != "arm64" ] && [ "$arch" != "aarch64" ]; then
    echo "ERROR: pulled image is '$arch', not arm64. Refusing to run a foreign binary under TCG." >&2
    echo "Build deploy/linxr/Dockerfile.llama.cpp on an arm64 host and load that image instead." >&2
    exit 1
  fi
}

start_llama() {
  docker rm -f jarvis-llama >/dev/null 2>&1 || true
  docker run -d --name jarvis-llama --restart unless-stopped \
    --network host --platform linux/arm64 \
    -v "$MODEL_DIR":/models:ro \
    "$IMAGE" \
    -m "/models/${MODEL_FILE}" \
    --host 0.0.0.0 --port 8080 \
    --alias "$ALIAS" --ctx-size "$CTX" --parallel 1
  echo "llama-server starting on :8080 (Linxr already forwards this to the phone)."
  echo "Health:  curl -sS http://127.0.0.1:8080/health"
  echo "Chat:    curl -sS http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"'"$ALIAS"'\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}'"
}

start_ollama() {
  echo "starting alpine/ollama on 11434 (Linxr already forwards this port)..."
  docker rm -f jarvis-ollama >/dev/null 2>&1 || true
  docker run -d --name jarvis-ollama --restart unless-stopped \
    --network host --platform linux/arm64 \
    -v "$MODEL_DIR":/models:ro \
    -v ollama_data:/root/.ollama \
    alpine/ollama:latest
  echo "waiting for Ollama..."
  i=0
  while [ "$i" -lt 40 ]; do
    if curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      break
    fi
    i=$((i + 1))
    sleep 1
  done
  if [ ! -f "$MODEL_PATH" ]; then
    place_model
  fi
  tmp=$(mktemp -d)
  cat > "$tmp/Modelfile" <<MF
FROM /models/${MODEL_FILE}
MF
  echo "creating Ollama model '$ALIAS' from the GGUF..."
  echo "NOTE: Ollama must support the lfm3 GGUF architecture. If this fails, use the default llama.cpp backend."
  if docker exec jarvis-ollama ollama create "$ALIAS" -f /models/Modelfile 2>/dev/null; then
    :
  else
    docker cp "$tmp/Modelfile" jarvis-ollama:/tmp/Modelfile
    if ! docker exec jarvis-ollama ollama create "$ALIAS" -f /tmp/Modelfile; then
      echo "Ollama could not import this GGUF. Falling back is: re-run without --backend ollama." >&2
      exit 1
    fi
  fi
  echo "Ollama API: http://127.0.0.1:11434  (OpenAI-compatible at /v1 if this build exposes it)"
}

start_cowork() {
  echo "WARNING: CoWork is Electron-based even in headless mode. On an 8 GB S23 + QEMU TCG this may OOM."
  if [ -z "$COMPOSE_DIR" ]; then
    echo "Pass --compose-dir /path/to/CoWork-OS-AI-OS/deploy/linxr to build the CoWork image." >&2
    exit 1
  fi
  ( cd "$COMPOSE_DIR" && docker compose --profile cowork up -d --build )
}

echo "== Jarvis Linxr setup =="
arch_ok
ensure_docker
place_model

if [ "$BACKEND" = "ollama" ]; then
  start_ollama
else
  pull_llama_image
  start_llama
fi

if [ "$WITH_COWORK" -eq 1 ]; then
  start_cowork
fi

echo "done. Keep CoWork approvals ON if you start the coworker later."
