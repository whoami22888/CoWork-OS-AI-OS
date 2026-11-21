# Jarvis portable folder (Windows)

A self-contained folder you copy onto a USB drive or disk and launch with
`Jarvis.bat`. It starts a Windows `llama-server` (LFM3 tiny tier by default,
adaptive routing when Python is available) and the CoWork CLI with the
Jarvis persona. The approval/permission engine stays **ON**.

This Linux build box **cannot** run Electron’s Windows packager or test the
`.bat` end-to-end. What is provided here is the folder layout, launchers,
fetch scripts, and exact steps to finish on a Windows x64 machine.

## Layout (what you copy)

```
JarvisPortable/                  # rename as you like; this is the folder you copy
  Jarvis.bat                     # double-click entry point
  Jarvis.ps1                     # same, for PowerShell
  README.md                      # this file (copied next to the launchers)
  bin/
    llama/                       # llama-server.exe + DLLs (Windows x64, b12600+)
    node/                        # Node.js >= 24 Windows x64 (portable zip)
  cowork/                        # CoWork tree (npm ci on Windows, or a packaged build)
  models/                        # LFM3 GGUF (or downloaded on first run)
  scripts/
    fetch-lfm3.ps1
    fetch-llama.ps1
    fetch-node.ps1
    select_model.py              # copied from repo scripts/
    profile_host.py
  workspace/                     # .cowork persona kit lands here
    .cowork/IDENTITY.md
    .cowork/SOUL.md
    .cowork/VIBES.md
```

`deploy/windows/layout/` in this repo is the template (launchers + scripts).
`assemble-folder.sh` (run on Linux or Git Bash) stages that skeleton into
`deploy/windows/dist/JarvisPortable/` and copies the persona + Python
selectors. It will also *download* the Windows llama.cpp and Node zip files
into `.cache/` when the network allows — those are **not** committed.

## Finish on Windows (required)

1. **llama.cpp (Windows x64, lfm3 support)**  
   Use a official `ggml-org/llama.cpp` release **b12600 or newer** (LFM3 landed
   around b11938 / PR #31252). Download the Ubuntu-equivalent **win-x64**
   `llama-*.zip` and unpack so `bin/llama/llama-server.exe` exists.
   The helper `scripts/fetch-llama.ps1` tries:

   `https://github.com/ggml-org/llama.cpp/releases/download/b12600/`  
   (file name changes per release; the script lists the release assets and
   picks a `*win*x64*` / `*windows*x64*` zip).

   ARM64 Windows (Snapdragon laptops): grab the matching win-arm64 zip instead
   and replace `bin/llama/`. This folder does not bundle both.

2. **Node.js >= 24 portable**  
   `scripts/fetch-node.ps1` pulls
   `https://nodejs.org/dist/v24.22.1/node-v24.22.1-win-x64.zip` into `bin/node/`.

3. **CoWork**  
   Copy this repository into `cowork/` **or** clone it there, then in that
   folder:

   ```powershell
   $env:PATH = "$PWD\..\bin\node;$env:PATH"
   npm ci
   ```

   Optional, better UX if you have a Windows machine with a working VS
   toolchain / Electron build:

   ```powershell
   npm run package:win:x64
   ```

   That produces an NSIS installer under `release/` — it is a *Windows-hosted*
   build. Cross-compiling it from Linux is not supported here (and was not
   run). The portable folder’s default path is the **CLI**, not that installer.

4. **LFM3 model** (1,132,208,000 bytes, not the 8B)  
   `scripts/fetch-lfm3.ps1` downloads
   `AtomicChat/LFM3-1.7B-Uncensored-GGUF` /
   `LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf` and checks
   SHA256 `b22df65673b54ed326f18f74826d76f3b65dadc237ffd6306cd52be04544827d`.

5. Double-click `Jarvis.bat`. First run may take a few minutes (model +
   server start). Then, in the same window or another:

   ```powershell
   .\Jarvis.bat -Chat "Introduce yourself as Jarvis_liquid_agent."
   ```

## Adding the 8B

Copy `mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf` (5,027,784,288 bytes,
SHA256 `361557e69ad101ee22b1baf427283b7ddcf81bc7532b8cee8ac2c6b4d1b81ead`)
into `models\` and re-run `Jarvis.bat`. On a capable PC, `select_model.py`
will pick it. If Python is missing, the launcher stays on LFM3 unless you
set `JARVIS_MODEL_FILE`.

## Approval engine

Launchers set `COWORK_APPROVAL_PROMPTS=on` and pass
`--access-profile ask_for_approval`. Do not turn this off.

## What this Linux box could and could not do

| Item | Status |
| --- | --- |
| Folder layout, `.bat` / `.ps1`, fetch scripts, README | Written in `deploy/windows/` |
| Persona kit + `select_model.py` / `profile_host.py` | Copied by `assemble-folder.sh` |
| Windows llama.cpp / Node zips | Downloadable by the fetch scripts (not committed) |
| `npm run package:win:x64` NSIS / Electron .exe | **Must be built and tested on Windows** |
| Running or signing the portable folder | **Must be tested on Windows** |
