# llama.cpp (local, not vendored)

Phase 1 uses a **prebuilt** [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) Ubuntu x64 CPU build that includes LFM3 support (upstream PR #31252). Binaries are gitignored.

Verified working tag for this branch: **b12600**.

```bash
gh release download b12600 -R ggml-org/llama.cpp -p 'llama-b12600-bin-ubuntu-x64.tar.gz'
mkdir -p tools/llama.cpp
tar -xzf llama-b12600-bin-ubuntu-x64.tar.gz -C tools/llama.cpp
./scripts/run-lfm3-server.sh
# OpenAI-compatible API: http://127.0.0.1:8080/v1
```

Windows later: use `llama-b12600-bin-win-cpu-x64.zip` from the same release on the user's PC.
