# Jarvis + CoWork OS — Docker delivery

Self-contained stack: **llama.cpp server** (OpenAI-compatible `/v1`) plus **CoWork OS headless/CLI**. The approval/permission engine stays on. GGUF weights are **not** baked into the image (they are large and gitignored); you mount `./models`.

This file is what you run later on a machine that has Docker (the Phase 2 dev box did not have a Docker daemon, so the image was not built there).

## What you need

- Docker Engine and Docker Compose v2
- A few GB of RAM for the tiny model, **~12 GB+ RAM** (or 8 GB+ VRAM) for the 8B main tier
- The GGUF files already in the repo's `models/` directory:

  - `mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf` (default, ~5.03 GB)
  - optionally `LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf` for the tiny tier

  Download instructions and SHA256 sums: `models/README.md`.

## Build and launch

From the **repository root**:

```bash
# Optional: see which tier this machine would pick
python3 scripts/select_model.py

docker compose -f deploy/jarvis/docker-compose.yml build
docker compose -f deploy/jarvis/docker-compose.yml up
```

Then:

- llama-server: `http://127.0.0.1:8080/v1`
- CoWork Control Plane: `http://127.0.0.1:18789`

In another terminal, with the same repo (or inside the `cowork` container):

```bash
docker compose -f deploy/jarvis/docker-compose.yml exec cowork \
  node bin/cowork-cli.js run "In one short sentence, introduce yourself as Jarvis." \
  --access-profile ask_for_approval
```

Stop with Ctrl+C, or `docker compose -f deploy/jarvis/docker-compose.yml down`.

## Switch tiers

Default is the mid-size Qwen3-8B abliterated GGUF. To run the tiny LFM3 model instead:

```bash
JARVIS_MODEL_FILE=LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf \
JARVIS_MODEL_ALIAS=LFM3-1.7B-Uncensored \
JARVIS_CTX=32768 \
docker compose -f deploy/jarvis/docker-compose.yml up
```

The `large` tier in `config/models.json` is a hook only — add a 14B–32B GGUF and raise `JARVIS_MODEL_FILE` when the host has enough VRAM or RAM.

## Notes

- Ports are published on `127.0.0.1` only. Do not publish them to `0.0.0.0` on an untrusted network.
- The llama.cpp image should be a recent `ghcr.io/ggml-org/llama.cpp:server` build. LFM3 needs a build that includes arch `lfm3` (around b12600 / PR #31252). Qwen3-8B runs on any reasonably current server image.
- Do not upload this stack to a random host without the owner's OK. Weights have their own licenses (LFM Open License v1.0 for LFM3; Apache-2.0 for the Qwen3 abliterated quant).

## ARM64 / Linxr

The default compose file above is for a desktop Docker host (x86_64, 8B default). For `linux/arm64` (Apple Silicon, Ampere, or Linxr on a phone) use the override, which **defaults to LFM3** and sets `platform: linux/arm64`:

```bash
docker compose -f deploy/jarvis/docker-compose.yml \
               -f deploy/jarvis/docker-compose.arm64.yml up
```

The Phase 1 `tools/llama.cpp/llama-b12600` Ubuntu **x64** binaries will not run on arm64. Use `ghcr.io/ggml-org/llama.cpp:server` and confirm `docker inspect ... --format '{{.Architecture}}'` is `arm64`.

On a Galaxy S23 / Linxr Alpine VM, do **not** start from this desktop compose. Use `deploy/linxr/` instead (tiny tier, host network, models on `/mnt/sdcard`, CoWork opt-in). That path was documented, not executed: this development box has no arm64 Docker daemon.

Phone-class hosts are capped at the tiny tier by `scripts/select_model.py` (see `config/models.json` `device_classes.phone`). The 8B model is an explicit opt-in (`JARVIS_ALLOW_MAIN=1`), not a phone default.

