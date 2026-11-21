#!/usr/bin/env python3
"""Host capacity probe. Stdlib only. Inspired by usb-agent-portable HostProfiler."""
from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _meminfo() -> dict[str, int]:
    info: dict[str, int] = {}
    path = Path("/proc/meminfo")
    if not path.exists():
        return info
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^(\w+):\s+(\d+)\s+kB", line)
        if m:
            info[m.group(1)] = int(m.group(2)) * 1024
    return info


def _vram_mb() -> tuple[int, int, str | None]:
    """Return (total_mb, used_mb, source) if a GPU is visible."""
    nvidia = shutil.which("nvidia-smi")
    if nvidia:
        try:
            out = subprocess.check_output(
                [
                    nvidia,
                    "--query-gpu=memory.total,memory.used",
                    "--format=csv,noheader,nounits",
                ],
                text=True,
                timeout=3,
            )
            totals, useds = [], []
            for line in out.strip().splitlines():
                parts = [p.strip() for p in line.split(",")]
                if len(parts) >= 2:
                    totals.append(int(float(parts[0])))
                    useds.append(int(float(parts[1])))
            if totals:
                return sum(totals), sum(useds), "nvidia-smi"
        except (subprocess.SubprocessError, ValueError, FileNotFoundError):
            pass
    return 0, 0, None


def profile(data_path: Path | None = None) -> dict:
    mem = _meminfo()
    total = int(mem.get("MemTotal", 0))
    available = int(mem.get("MemAvailable", mem.get("MemFree", 0)))
    disk = shutil.disk_usage(str(data_path or ROOT))
    vram_total, vram_used, vram_source = _vram_mb()
    total_mb = total // 1_000_000
    available_mb = available // 1_000_000

    if total_mb < 4_000:
        name = "ULTRA_LOW"
    elif total_mb < 8_000:
        name = "LOW"
    elif total_mb < 16_000:
        name = "MEDIUM"
    elif total_mb < 32_000:
        name = "HIGH"
    elif total_mb < 64_000:
        name = "WORKSTATION"
    else:
        name = "SERVER"

    return {
        "profile": name,
        "os_name": platform.system(),
        "machine": platform.machine(),
        "cpu_cores": os.cpu_count() or 1,
        "memory_total_mb": total_mb,
        "memory_available_mb": available_mb,
        "disk_free_mb": disk.free // 1_000_000,
        "vram_total_mb": vram_total,
        "vram_used_mb": vram_used,
        "vram_source": vram_source,
    }


def main() -> None:
    print(json.dumps(profile(), indent=2))


if __name__ == "__main__":
    main()
