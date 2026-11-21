# Jarvis on Linxr (Galaxy S23 / Alpine arm64 VM)

This folder is how you run the Jarvis CoWork stack **inside Linxr's Alpine Linux VM** on an arm64 Android phone. The development box that wrote these files is x86_64 and has **no arm64 Docker daemon**, so nothing here was pulled, built, or run on-device. Treat every image pull and first start as an on-device verification step.

Target device: Samsung Galaxy S23, arm64, 8 GB RAM, CPU only (no usable GPU inside the VM). Linxr's QEMU is TCG, so the guest is already slower than native ARM — roughly 3× according to Linxr's own notes. Keep the always-on model at the **tiny** tier (LFM3 1.7B Q4_K_M, 1.13 GB).

## Recommended path for the S23

**SSH (or the Linxr Terminal tab) + `setup-in-vm.sh`, serving LFM3 with official `llama.cpp` on port 8080.**

Why this, and not the built-in Ollama 1-click recipe as the default:

- LFM3 uses llama.cpp arch `lfm3`. Phase 1 proved it loads on llama.cpp **b12600**. Ollama's support for that arch is **unverified**.
- Linxr's marketplace Docker recipes cannot bind-mount `/mnt/sdcard`, so a 1-click `docker` recipe cannot attach the GGUF. A **script** recipe can, and one is included: `jarvis-llama.recipe.json`.
- Port **8080** is already in Linxr's default Chrome forwards. After start, open `http://localhost:8080` on the phone (llama-server has a small web UI and `/v1`).
- CoWork (Electron, even headless) is an optional later step. On 8 GB + TCG it is likely to OOM. Approvals stay **on** if you start it.

Ollama on 11434 remains a documented fallback (`sh setup-in-vm.sh --backend ollama`) if you prefer the official 1-click engine and it can import this GGUF.

## What to put where

| Place | Path |
|---|---|
| Android (Files / SAF) | `/storage/emulated/0/LinxrShare/JarvisModels/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf` |
| Inside the VM | `/mnt/sdcard/JarvisModels/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf` |
| Size / SHA256 | `1,132,208,000` bytes / `b22df65673b54ed326f18f74826d76f3b65dadc237ffd6306cd52be04544827d` |
| Public copy | https://huggingface.co/AtomicChat/LFM3-1.7B-Uncensored-GGUF (same GGUF as the Drive file) |

Copy the GGUF onto the phone first (USB, Drive, or Wi-Fi). Do not store it only in the QCOW2 overlay if you can avoid it — the 9P share at `/mnt/sdcard` survives a VM reset of `user.qcow2` only if the file is on Android storage.

## Linxr Settings (before you start)

Suggested VM sliders on an 8 GB S23:

- **RAM:** 4096 MB if Android stays stable; 3072 MB is the floor for LFM3 + llama-server. Leave a few GB for Android or the VM will be killed.
- **vCPU:** 4
- **Disk:** 10 GB is enough for llama-server + the official image if the GGUF lives on `/mnt/sdcard`. Budget **16 GB+** if you also build the CoWork image.
- Start the VM, confirm Docker can be started (Linxr starts the engine on demand).

## Path A — SSH / Terminal (recommended)

From the Linxr Terminal tab, or `ssh root@localhost -p 2222` (password under **Settings → SSH access**):

```sh
# 1. Copy this folder onto the share, then:
cd /mnt/sdcard/CoWork-OS-AI-OS/deploy/linxr   # or wherever you placed the repo

# 2. If the GGUF is not already in JarvisModels/:
sh setup-in-vm.sh --download-model

# 3. Otherwise:
sh setup-in-vm.sh
```

The script will `apk add` Docker if needed, pull `ghcr.io/ggml-org/llama.cpp:server` for **linux/arm64**, refuse to run if the image architecture is not arm64, and start `jarvis-llama` on `:8080` with `--ctx-size 8192`.

Checks inside the VM:

```sh
docker inspect ghcr.io/ggml-org/llama.cpp:server --format '{{.Architecture}}'   # must be arm64
curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"LFM3-1.7B-Uncensored","messages":[{"role":"user","content":"ping"}]}'
```

On the phone, Chrome → `http://localhost:8080`.

Do **not** use the Phase 1 `tools/llama.cpp/llama-b12600` Ubuntu **x64** tarball. It will not run on arm64.

## Path B — Import the marketplace recipe

`jarvis-llama.recipe.json` matches Linxr's custom-recipe schema (`id`, `type: script`, `script`, `ports`, `network: host`). In Linxr: **Marketplace → import** the JSON, then deploy.

The script recipe starts Docker if needed, bind-mounts `/mnt/sdcard/JarvisModels`, and runs the same llama-server container. It **exits with an error** (and a path hint) if the GGUF is missing — it does not download 1.13 GB by itself.

This is not in Linxr's official catalog (`AI2TH/linxr-marketplace`). It is a user-imported custom recipe.

## Path C — Ollama (fallback, unverified for LFM3)

Linxr already ships a 1-click **Ollama LLM Engine** recipe (`alpine/ollama:latest`, port **11434**, also pre-forwarded). If you want CoWork talking to Ollama later:

```sh
sh setup-in-vm.sh --backend ollama
# or: 1-click the official recipe, then import the GGUF
```

`ollama create` must accept arch `lfm3`. If it errors, go back to Path A. Do not assume `/v1` exists on every Ollama build; confirm `curl http://127.0.0.1:11434/v1/models` on-device.

A tiny Ollama-native model such as `smollm:135m` will run, but it is not the Jarvis LFM3 weights.

## Optional: CoWork headless (not the S23 default)

CoWork's `Dockerfile` is `node:24-bookworm-slim` (multi-arch) plus Electron + Xvfb. That image is large, the first arm64 build is slow, and native modules (`better-sqlite3`) must compile **on** arm64.

```sh
# from this directory, after llama-server is healthy
docker compose --profile cowork up -d --build
# or: sh setup-in-vm.sh --with-cowork --compose-dir "$PWD"
```

Keep `COWORK_APPROVAL_PROMPTS=on` and the `ask_for_approval` access profile. Do not turn the permission engine off.

**Context-window caveat:** Phase 1 needed `--ctx-size 32768` because a CoWork tool prompt was **13,079 tokens**. The phone default is **8192** so the 8 GB VM can actually load the model. CoWork CLI tool-use may therefore fail with a context overflow on the S23 until you raise `JARVIS_CTX` (try 16384 only if `free -m` still looks healthy). The llama-server web UI and short `/v1` chats are the realistic first test.

## ARM64 image notes

- Official docs list `ghcr.io/ggml-org/llama.cpp:server` as multi-arch (`linux/amd64`, `linux/arm64`). Historically the arm64 manifest has been overwritten by amd64 builds; **always inspect Architecture on-device**.
- If the pull is the wrong arch or lacks `lfm3`, either:
  1. Download a `llama-b*-bin-ubuntu-arm64.tar.gz` release from ggml-org/llama.cpp and run it in an `ubuntu:24.04` container, or
  2. Build `Dockerfile.llama.cpp` on a faster arm64 machine (building inside Linxr TCG may take hours) and `docker load` the image.
- `deploy/jarvis/docker-compose.arm64.yml` is the same idea for a regular arm64 Linux/Mac host (still defaults to LFM3). Desktop x86 keeps using `deploy/jarvis/docker-compose.yml` (8B default).

## Footprint estimate (S23)

| Item | Disk | RAM (runtime, rough) |
|---|---|---|
| LFM3 Q4_K_M GGUF | 1.13 GB (prefer `/mnt/sdcard`) | ~1.5–2.5 GB with 8k context |
| `llama.cpp:server` image | ~0.2–0.5 GB (verify on pull) | included above |
| Alpine VM + Docker engine | already in Linxr | hundreds of MB |
| CoWork image (optional) | ~1.5–3 GB build | +0.5–1.5 GB, high OOM risk |
| Qwen3-8B Q4_K_M | 5.03 GB | impractical on this phone CPU / 8 GB |

Expect a few tokens per second at best, not the ~32 tok/s seen on the x86 Phase 1 box. First token will be slow. If Android evicts the VM, drop `JARVIS_CTX` to 4096 and do not start CoWork.

## What was proved on the development box vs on-device

Proved here (x86_64, no Docker daemon, no S23):

- `python3 scripts/select_model.py --simulate phone` → tier `tiny`, alias `LFM3-1.7B-Uncensored`, ctx `8192`.
- The same selector on this 16 GB desktop host still picks `main` (Qwen3-8B).
- YAML of `deploy/linxr/docker-compose.yml` and `deploy/jarvis/docker-compose.arm64.yml` parses. Dockerfiles were linted where the linter is available.
- Recipe JSON matches Linxr's `MarketplaceItem` export shape.

Needs the S23 / Linxr VM:

- `docker pull --platform linux/arm64` actually yields an arm64 image with `lfm3` support.
- Model load + a `/v1` chat through the 8080 forward.
- Recipe import + deploy from the Marketplace UI.
- Ollama import of this GGUF (if you try Path C).
- Any CoWork CLI run, especially with an 8k or 16k context.
- Real RAM, thermal, and token/s numbers.
- Whether `/dev/tcp` healthchecks work in the official server image (the start script does not depend on them).

## License

LFM3 weights: LFM Open License v1.0 (commercial cap applies). CoWork OS: MIT. Do not publish the GGUF in an image.
