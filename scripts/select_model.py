#!/usr/bin/env python3
"""Pick the largest enabled model tier this host can run."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from profile_host import profile  # noqa: E402


def load_config(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def select(cfg: dict, host: dict, root: Path) -> dict:
    fallback_id = cfg.get("selection", {}).get("fallback", "tiny")
    require_file = cfg.get("selection", {}).get("require_file", True)
    tiers = [t for t in cfg.get("tiers", []) if t.get("enabled", True)]
    # largest-fitting: prefer higher min_ram, then min_vram
    tiers_sorted = sorted(
        tiers,
        key=lambda t: (int(t.get("min_vram_mb") or 0), int(t.get("min_ram_mb") or 0)),
        reverse=True,
    )

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

    reason = []
    if chosen.get("id") == fallback_id and not any(fits(t) for t in tiers_sorted if t.get("id") != fallback_id):
        reason.append("no larger enabled tier fits this host or its GGUF is missing")
    else:
        reason.append("largest enabled tier whose RAM/VRAM thresholds this host meets")
    if require_file and chosen.get("file") and not file_ok(chosen):
        reason.append("WARNING: selected GGUF is not on disk")

    return {
        "host": host,
        "tier": chosen.get("id"),
        "alias": chosen.get("alias") or chosen.get("name"),
        "model_path": str(root / chosen["file"]) if chosen.get("file") else None,
        "ctx_size": chosen.get("ctx_size"),
        "role": chosen.get("role"),
        "reason": "; ".join(reason),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=str(ROOT / "config" / "models.json"))
    parser.add_argument("--json", action="store_true", help="print only JSON")
    args = parser.parse_args()
    cfg = load_config(Path(args.config))
    result = select(cfg, profile(), ROOT)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
