# Phase 3 (Linxr / arm64 phone) — what was proved on the development box

Date: 2026-11-21 (Australia/Sydney). Branch: `feat/jarvis-lfm3-local-phase1`.

This box is x86_64, has no Docker daemon, and is not a Galaxy S23. The selector was proved here. Image pulls, VM boot, and token/s were not.

## Selector

```
python3 scripts/select_model.py --simulate phone
```

Result in `selection-phone.json`: `device_class=phone`, `tier=tiny`, alias `LFM3-1.7B-Uncensored`, `ctx_size=8192`.

The live 16 GB x86 host still picks `main` (`selection-this-host.json`).

## Artifacts

- `deploy/linxr/` — README, compose (LFM3 default, CoWork profile opt-in), setup-in-vm.sh, importable Linxr script recipe, source-build Dockerfile fallback.
- `deploy/jarvis/docker-compose.arm64.yml` — arm64 override, also defaults to LFM3.
- `config/models.json` — `device_classes.phone` caps the max tier at `tiny`.

## Lint

- `sh -n deploy/linxr/setup-in-vm.sh` passed.
- Compose and override YAML parsed; llama service is `platform: linux/arm64`, host network, LFM3 default; CoWork profile keeps `COWORK_APPROVAL_PROMPTS=on`.
- Recipe JSON matches Linxr `MarketplaceItem` shape (`type: script`, port 8080, `network: host`).
- `hadolint` and `docker compose config` were not available on this box.
