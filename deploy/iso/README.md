# Jarvis live ISO (Debian)

A bootable Debian Bookworm **iso-hybrid** (BIOS + UEFI) that starts the
Jarvis stack on boot:

- `llama-server` on `127.0.0.1:8080/v1`, default **tiny** tier (LFM3-1.7B-Uncensored Q4_K_M)
- Adaptive routing via `scripts/profile_host.py` + `scripts/select_model.py`
- CoWork **headless/CLI** with the Jarvis persona
- Human-approval permission engine **ON** (`ask_for_approval`, `COWORK_APPROVAL_PROMPTS=on`)
- A light **Xfce** session with a “Jarvis Chat” launcher (`jarvis-chat "…"`)

The Electron desktop app is **not** baked into this ISO (it would need a
separate Linux Electron package and would balloon the image). The CLI and
the local OpenAI-compatible server are the supported live-session path.

## One-command build

On a Debian/Ubuntu **amd64** machine with sudo and ~25 GB free:

```bash
sudo apt-get update
sudo apt-get install -y live-build xorriso squashfs-tools debootstrap isolinux \
  syslinux-common grub-pc-bin grub-efi-amd64-bin cpio rsync curl python3 ca-certificates

# From the CoWork-OS-AI-OS repo root, on branch feat/jarvis-lfm3-local-phase1:
#  - node_modules must already exist (`npm ci`; Node >= 24)
#  - tools/llama.cpp/llama-b12600/llama-server must exist (linux-x64, b12600+ with lfm3)
#  - models/LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf is optional (see below)

INCLUDE_LFM3=1 ./deploy/iso/build.sh
```

The ISO is written to `deploy/iso/dist/jarvis-live-amd64.iso` (and, if
`/workspace` exists, also copied there) with a sibling `.sha256`.

| Env | Default | Meaning |
| --- | --- | --- |
| `INCLUDE_LFM3=1` | `auto` → 1 if the GGUF is on the build host | Bake the 1.13 GiB LFM3 into the ISO (offline first boot) |
| `INCLUDE_LFM3=0` | | Smaller ISO; first boot downloads LFM3 from Hugging Face and verifies SHA256 |

**The 8B model is never baked in.** See `/opt/jarvis/models/ADD-8B.txt` inside
the live system (and “Adding the 8B” below).

### Expected size

- Without LFM3: typically **~1.5–2.5 GiB** (Debian + Xfce + Node 24 + llama.cpp + CoWork `node_modules`).
- With LFM3 (`INCLUDE_LFM3=1`): add **~1.13 GiB** raw; squashfs compresses the rest, so plan on **~2.5–3.5 GiB**.
- Adding the 8B yourself after boot is another **~5.03 GiB** on disk, not in the ISO.

Exact bytes and SHA256 are printed by `build.sh` when the ISO is produced.

## What auto-starts

systemd units (enabled in the image):

1. `jarvis-first-boot.service` — install the Jarvis persona into
   `/home/user/jarvis-workspace/.cowork`, fetch/verify LFM3 if needed.
2. `jarvis-llama.service` — run `select_model.py` and start `llama-server`
   with the chosen GGUF + context size, bound to **127.0.0.1 only**.
3. `jarvis-cowork.service` — wait for `/v1/models`, configure CoWork’s
   `openai-compatible` provider, start the node-only daemon if present.

Login: Debian live default user `user` (this image sets NOPASSWD sudo for that
live user). Persistence is enabled in the boot line (`persistence`); a second
partition labelled `persistence` will keep `/opt/jarvis/models` and the
workspace across reboots if you set it up (standard live-boot persistence).

Chat:

```bash
jarvis-chat "In one short sentence, introduce yourself as Jarvis_liquid_agent."
```

## Adding the 8B (main tier)

Do **not** rebuild the ISO. On a capable machine, copy:

- File: `mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf` (5,027,784,288 bytes)
- SHA256: `361557e69ad101ee22b1baf427283b7ddcf81bc7532b8cee8ac2c6b4d1b81ead`
- Source: https://huggingface.co/bartowski/mlabonne_Qwen3-8B-abliterated-GGUF

into `/opt/jarvis/models/` and restart `jarvis-llama.service`.
`select_model.py` will pick it when RAM/VRAM thresholds in `config/models.json`
are met. Phone-class hosts stay on LFM3 unless `JARVIS_ALLOW_MAIN=1`.

## Approval engine

The permission engine is **not** disabled. CLI calls use
`--access-profile ask_for_approval`. Real/state-changing tools still require
a human yes.

## Layout in this directory

```
deploy/iso/
  build.sh              # one-command ISO build
  prepare_payload.sh    # fills the gitignored .build/ tree
  README.md
  live-config/          # lb auto/config, package list, chroot hook
  skel/                 # files copied into the live filesystem
  .build/               # gitignored live-build workdir
  .cache/               # gitignored Node tarball
  dist/                 # gitignored output ISO
```

Adapted from the `usb-agent-portable/bootable/` live-build approach
(Debian iso-hybrid, isolinux path fix, includes.chroot payload).
