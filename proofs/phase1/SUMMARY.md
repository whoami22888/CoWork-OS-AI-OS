# Phase 1 proof summary

Date: 2026-11-21 (Australia/Sydney). Branch: `feat/jarvis-lfm3-local-phase1`.

## Model

- File: `models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf`
- Size: 1,132,208,000 bytes (exact match)
- SHA256: `b22df65673b54ed326f18f74826d76f3b65dadc237ffd6306cd52be04544827d` (matches the public Hugging Face card)
- Drive `DownloadFile` cannot fetch files over 100 MB, so the same public AtomicChat GGUF was pulled from Hugging Face and hash-verified.

## llama.cpp

- Prebuilt `ggml-org/llama.cpp` **b12600** (`llama-b12600-bin-ubuntu-x64`), CPU.
- **LFM3 loaded successfully** (arch `lfm3`, Q4_K_M, 1.728B params).
- `llama-cli` reply: "I'm Jarvis, your AI coworker." (~32 tok/s).
- `llama-server` OpenAI-compatible API on `http://127.0.0.1:8080/v1`.
- First CoWork attempt failed: context 4096 < a 13,079-token CoWork prompt. Restarted with `--ctx-size 32768`. Then it worked.

## CoWork CLI

- Node v24.22.1, `npm install` (1238 packages), `npm run build:cli` succeeded.
- Provider: `cowork providers configure openai-compatible --model LFM3-1.7B-Uncensored --base-url http://127.0.0.1:8080/v1`
- Workspace: `proofs/jarvis-workspace` with Jarvis persona copied into `.cowork/`.
- Access profile: **`ask_for_approval` left on**. Permission engine was not disabled.

### Chat task `595807d4-f373-4104-b3c5-a58b5c14be3d` — PASSED

> I'm Jarvis, the coworker and local co-pilot for this workspace, here to read, write, organise, and automate work for you.

Status: `completed`. Log: `cowork-chat.log`.

### Tool task `098a969e-32d9-4dd9-81b6-0ca55946be0e` — PASSED with caveats

- Tool call: `write_file` path `hello-from-jarvis.txt` content `Consider it done.`
- Tool result: `success: true`
- File on disk: `proofs/jarvis-workspace/hello-from-jarvis.txt` (17 bytes, exact content).
- Task status: `completed` / `partial_success`.
- Caveat 1: the model then **misreported the path** as `/workspace/hello-from-jarvis.txt` (wrong). The file was actually written in the workspace root. 1.7B tool-use is shaky.
- Caveat 2: CoWork also inferred `run_command` as a required tool. We told it not to use the shell; `run_command` was not called, so a step was marked failed even though the file write succeeded.
- Caveat 3: **no approval popup / pending approval row**. That is CoWork's documented default for in-workspace file creates under `ask_for_approval` (those writes are pre-authorized). The engine was still on; nothing was auto-approved that should have been asked. CLI approval handoff (`cowork approve`) needs the desktop app or a running Control Plane, which this headless box does not have.
- Evidence: `tool-events.json`, `cowork-tool.log`, mutation ledger, the file itself.

## Persona

Committed templates (new text, not JARVIS-AGI AVA prompts):

- `resources/jarvis-persona/IDENTITY.md`
- `resources/jarvis-persona/SOUL.md`
- `resources/jarvis-persona/VIBES.md`

Install into a workspace with `scripts/install-jarvis-persona.sh`.

## Not done here

- Electron GUI, wake-word / always-on voice, Windows package, USB / Linux live ISO.
- No Docker on this box, so CoWork's Linux OS command sandbox is unavailable (shell would fail closed on restricted profiles). File tools still work.
- Connectors (Google Drive, GitHub, etc.) are already in `connectors/` as MCP packs but were not authenticated in this pass.
