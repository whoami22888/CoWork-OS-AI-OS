#!/usr/bin/env python3
"""Pick the largest enabled model tier this host can run."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from profile_host import profile  # noqa: E402


def load_config(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def select(cfg: dict, host: dict, root: Path, allow_main: bool = False) -> dict:
    fallback_id = cfg.get("selection", {}).get("fallback", "tiny")
    require_file = cfg.get("selection", {}).get("require_file", True)
    tiers = [t for t in cfg.get("tiers", []) if t.get("enabled", True)]
    tiers_by_id = {t.get("id"): t for t in cfg.get("tiers", [])}
    tiers_sorted = sorted(
        tiers,
        key=lambda t: (int(t.get("min_vram_mb") or 0), int(t.get("min_ram_mb") or 0)),
        reverse=True,
    )

    device_class = host.get("device_class") or "desktop"
    class_cfg = (cfg.get("device_classes") or {}).get(device_class) or {}
    max_tier = class_cfg.get("max_tier")
    ctx_override = class_cfg.get("ctx_size_override")
    if max_tier and not allow_main:
        allowed = []
        for t in tiers_sorted:
            # keep tiers at or below max_tier by min_ram
            cap = tiers_by_id.get(max_tier) or {}
            if int(t.get("min_ram_mb") or 0) <= int(cap.get("min_ram_mb") or 0) or t.get("id") == max_tier:
                allowed.append(t)
        if allowed:
            tiers_sorted = allowed

    def file_ok(tier: dict) -> bool:
        rel = tier.get("file")
        if not rel:
            return False
        return (root / rel).is_file()

    def fits(tier: dict) -> bool:
        if require_file and not file_ok(tier):
            return False
        if host["memory_total_mb"] < int(tier.get("min_ram_mb") or 0):
            return False
        need_vram = int(tier.get("min_vram_mb") or 0)
        if need_vram and host["vram_total_mb"] < need_vram:
            return False
        return True

    chosen = next((t for t in tiers_sorted if fits(t)), None)
    if chosen is None:
        chosen = next((t for t in tiers if t.get("id") == fallback_id), tiers[-1] if tiers else {})

    ctx = chosen.get("ctx_size")
    if ctx_override and (not allow_main or chosen.get("id") == max_tier):
        ctx = ctx_override

    reason = []
    if device_class == "phone" and not allow_main:
        reason.append("phone-class host (arm64, no GPU, under 10 GB RAM); capped at tiny")
    elif chosen.get("id") == fallback_id and not any(
        fits(t) for t in tiers_sorted if t.get("id") != fallback_id
    ):
        reason.append("no larger enabled tier fits this host or its GGUF is missing")
    else:
        reason.append("largest enabled tier whose RAM/VRAM thresholds this host meets")
    if require_file and chosen.get("file") and not file_ok(chosen):
        reason.append("WARNING: selected GGUF is not on disk")

    return {
        "host": host,
        "device_class": device_class,
        "tier": chosen.get("id"),
        "alias": chosen.get("alias") or chosen.get("name"),
        "model_path": str(root / chosen["file"]) if chosen.get("file") else None,
        "ctx_size": ctx,
        "role": chosen.get("role"),
        "reason": "; ".join(reason),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=str(ROOT / "config" / "models.json"))
    parser.add_argument("--simulate", choices=["phone", "workstation"], help="fake a host class")
    parser.add_argument(
        "--allow-main",
        action="store_true",
        help="allow the 8B tier even on a phone-class host (not recommended on an S23)",
    )
    args = parser.parse_args()
    allow = args.allow_main or os.environ.get("JARVIS_ALLOW_MAIN") == "1"
    cfg = load_config(Path(args.config))
    result = select(cfg, profile(simulate=args.simulate), ROOT, allow_main=allow)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
