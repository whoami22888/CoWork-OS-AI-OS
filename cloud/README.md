# ☁️ Free cloud Jarvis (Kaggle / Colab)

`jarvis_kaggle.ipynb` runs **Jarvis_liquid_agent** (model: [AtomicChat/LFM3-1.7B-Uncensored-GGUF](https://huggingface.co/AtomicChat/LFM3-1.7B-Uncensored-GGUF), `LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf`) on a free T4 GPU using official prebuilt [llama.cpp](https://github.com/ggml-org/llama.cpp/releases) CUDA binaries, and publishes it through a free **Cloudflare quick tunnel** (`*.trycloudflare.com`, no account). Open the printed link on your phone to get llama.cpp's chat UI; `<url>/v1` is an OpenAI-compatible API (model `Jarvis_liquid_agent`). A tiny proxy injects the Jarvis persona as the system prompt.

## Colab (one click)
[![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/whoami22888/CoWork-OS-AI-OS/blob/main/cloud/jarvis_kaggle.ipynb)
Runtime → Change runtime type → **T4 GPU** → Runtime → **Run all**.

## Kaggle (more free GPU hours, ~30 h/week)
1. Sign in at kaggle.com and **phone-verify** your account (Settings → Phone verification), needed for Internet access.
2. **Create → New Notebook → File → Import Notebook** → GitHub / URL: `https://github.com/whoami22888/CoWork-OS-AI-OS/blob/main/cloud/jarvis_kaggle.ipynb`
3. Right panel **Settings**: Accelerator **GPU T4 x2** (or P100), **Internet ON**.
4. **Run all** and open the big `https://….trycloudflare.com` link on your phone.

Optional password: set `API_KEY` in cell 1 (llama-server `--api-key`), then enter it in the web UI settings.
The link changes every run; the last cell keeps the session alive.
