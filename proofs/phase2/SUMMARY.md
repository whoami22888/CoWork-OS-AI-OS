# Phase 2 proof summary

Date: 2026-11-21 (Australia/Sydney). Branch: `feat/jarvis-lfm3-local-phase1`.

## Mid-size uncensored fallback

- Repo: https://huggingface.co/bartowski/mlabonne_Qwen3-8B-abliterated-GGUF
- File: `mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf`
- Size: 5,027,784,288 bytes (exact)
- SHA256: `361557e69ad101ee22b1baf427283b7ddcf81bc7532b8cee8ac2c6b4d1b81ead` (matches HF LFS oid)
- Base: `mlabonne/Qwen3-8B-abliterated`, Apache-2.0, ungated. bartowski imatrix quant.
- Downloads at selection: ~160.7k on the bartowski repo (hub overview).
- Stored at `models/` (gitignored).

llama.cpp **b12600** loaded it (arch `qwen3`, Q4_K_M).

Throughput on this 8-core CPU box, no GPU:

- Prompt: ~67–72 tok/s
- Generation: ~9 tok/s with `--reasoning off` (~5.4 tok/s with thinking left on)
- Compare Phase 1 LFM3-1.7B: ~213 / ~32 tok/s

`llama-cli --reasoning off`: "I am Jarvis, your concise and reliable coworker."

`llama-server` `/v1/chat/completions`: "I am online and ready to work."

### CoWork CLI

Access profile: **`ask_for_approval` left on**.

**Chat** task `9951a310-0f89-4ef1-ad43-3ca71fdd244e` — passed (took ~6 minutes; two mid-request aborts then retries, because a 13k-token CoWork prompt is slow on CPU).

> I'm Jarvis, the coworker and local co-pilot for this workspace, here to read, write, organize, and automate work on request. Let's get started.

**Tool** task `3bfbf69d-0c18-43e9-8c25-3bc7609ff867` — the model *did* emit a `write_file` call with content `Consider it done.`, but it used the absolute path `/workspace/hello-from-jarvis-8b.txt` (outside the CoWork workspace). The permission engine blocked it: status `blocked` / `awaiting_approval`, approval type `external_file_access`, pending id `c105f0d8-76a6-455f-a16f-9dc3e5a0b830`. The file was **not** written at that path. A CoWork bootstrap stub (`Bootstrap artifact stub.`) appeared in the workspace path; that is not the requested content.

Headless `cowork approve` needs the desktop app or Control Plane, so the approval was left pending on purpose (we would not silently allow a write outside the workspace).

### Tool-use vs LFM3 (blunt)

- LFM3 used a *relative* workspace path and successfully wrote the exact line, then lied about the absolute path in its final sentence.
- The 8B planned more clearly and sent the correct file content, but aimed at the wrong absolute path and was correctly stopped by approvals.
- So: stronger planning / correct tool + content, **not** clearly more reliable path discipline on this one test. CPU slowness also made CoWork abort and retry requests.

## Adaptive routing

- `config/models.json` — tiers: `tiny` (LFM3 1.7B), `main` (this 8B), `large` (disabled hook, 32 GB RAM or 16 GB VRAM).
- `scripts/profile_host.py` — stdlib host probe (RAM, CPU, disk, optional `nvidia-smi` VRAM), same profile names as usb-agent-portable.
- `scripts/select_model.py` and `scripts/run-local-server.sh`.

This box: 16.8 GB RAM (decimal), 0 VRAM, profile **HIGH**. Selector picked **`main`** (Qwen3-8B-abliterated). Proof: `proofs/phase2/selection.json`.

## Docker

- `deploy/jarvis/docker-compose.yml`, `entrypoint-configure.sh`, `README.md`.
- Bundles official `ghcr.io/ggml-org/llama.cpp:server` + existing CoWork `Dockerfile`. Models are bind-mounted, not baked in. Ports on `127.0.0.1` only. Approvals stay on.
- **Not built**: this box has no Docker daemon. Compose/entrypoint were linted with a basic structural check. hadolint on the pre-existing root Dockerfile only reported unpinned apt packages (DL3008); that file was not rewritten.

## Not done (needs the user's machine)

Windows USB, Linux live ISO, voice, connector OAuth. No image upload.
