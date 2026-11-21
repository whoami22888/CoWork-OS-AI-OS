# Local models (gitignored)

Do not commit GGUF files.

## Tiny — always-on

- `LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf` — 1,132,208,000 bytes
- SHA256 `b22df65673b54ed326f18f74826d76f3b65dadc237ffd6306cd52be04544827d`
- Source: AtomicChat GGUF of Liquid AI LFM3-1.7B (LFM Open License v1.0). Drive `DownloadFile` is capped at 100 MB, so Phase 1 used the public Hugging Face copy.

## Main — mid-size uncensored fallback

- `mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf` — 5,027,784,288 bytes
- SHA256 `361557e69ad101ee22b1baf427283b7ddcf81bc7532b8cee8ac2c6b4d1b81ead`
- Hugging Face: https://huggingface.co/bartowski/mlabonne_Qwen3-8B-abliterated-GGUF
- File: `mlabonne_Qwen3-8B-abliterated-Q4_K_M.gguf`
- Base: `mlabonne/Qwen3-8B-abliterated` (Apache-2.0, ungated). bartowski imatrix quant.
- ~160k downloads on the bartowski repo at selection time.

## Large

Not bundled. `config/models.json` has a disabled `large` hook for a 14B–32B GGUF when VRAM/RAM allows.

The selector in `scripts/select_model.py` picks a tier from host RAM/VRAM. Keep CoWork's approval/permission engine on — these weights are abliterated/uncensored.
