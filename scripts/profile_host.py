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

PHONE_ARCH = {"aarch64", "arm64", "armv8l"}
PHONE_RAM_MB = 10240


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


def classify_device(machine: str, total_mb: int, vram_mb: int) -> str:
    """phone = arm64, no usable GPU, under 10 GB RAM, or a Linxr guest."""
    arch = (machine or "").lower()
    linxr = Path("/etc/linxr-release").is_file() or os.environ.get("LINXR") == "1"
    if (arch in PHONE_ARCH or linxr) and vram_mb <= 0 and total_mb < PHONE_RAM_MB:
        return "phone"
    if vram_mb >= 16_000 or total_mb >= 32_000:
        return "workstation"
    return "desktop"


def _capacity_name(total_mb: int) -> str:
    if total_mb < 4_000:
        return "ULTRA_LOW"
    if total_mb < 8_000:
        return "LOW"
    if total_mb < 16_000:
        return "MEDIUM"
    if total_mb < 32_000:
        return "HIGH"
    if total_mb < 64_000:
        return "WORKSTATION"
    return "SERVER"


def profile(data_path: Path | None = None, simulate: str | None = None) -> dict:
    if simulate == "phone":
        # Galaxy S23-class Linxr VM: arm64, 8 GB, no GPU.
        return {
            "profile": "LOW",
            "device_class": "phone",
            "os_name": "Linux",
            "machine": "aarch64",
            "cpu_cores": 8,
            "memory_total_mb": 8000,
            "memory_available_mb": 3500,
            "disk_free_mb": 10_000,
            "vram_total_mb": 0,
            "vram_used_mb": 0,
            "vram_source": None,
            "simulated": True,
        }
    if simulate == "workstation":
        return {
            "profile": "WORKSTATION",
            "device_class": "workstation",
            "os_name": "Linux",
            "machine": "x86_64",
            "cpu_cores": 16,
            "memory_total_mb": 64_000,
            "memory_available_mb": 48_000,
            "disk_free_mb": 500_000,
            "vram_total_mb": 24_000,
            "vram_used_mb": 0,
            "vram_source": "simulated",
            "simulated": True,
        }

    mem = _meminfo()
    total = int(mem.get("MemTotal", 0))
    available = int(mem.get("MemAvailable", mem.get("MemFree", 0)))
    disk = shutil.disk_usage(str(data_path or ROOT))
    vram_total, vram_used, vram_source = _vram_mb()
    total_mb = total // 1_000_000
    available_mb = available // 1_000_000
    machine = platform.machine()
    return {
        "profile": _capacity_name(total_mb),
        "device_class": classify_device(machine, total_mb, vram_total),
        "os_name": platform.system(),
        "machine": machine,
        "cpu_cores": os.cpu_count() or 1,
        "memory_total_mb": total_mb,
        "memory_available_mb": available_mb,
        "disk_free_mb": disk.free // 1_000_000,
        "vram_total_mb": vram_total,
        "vram_used_mb": vram_used,
        "vram_source": vram_source,
        "simulated": False,
    }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulate", choices=["phone", "workstation"])
    args = parser.parse_args()
    print(json.dumps(profile(simulate=args.simulate), indent=2))


if __name__ == "__main__":
    main()
