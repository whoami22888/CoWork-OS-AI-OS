#!/usr/bin/env bash
# Copy the committed Jarvis persona into a CoWork workspace kit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/resources/jarvis-persona"
DEST="${1:-$ROOT/proofs/jarvis-workspace/.cowork}"
mkdir -p "$DEST"
cp -f "$SRC/IDENTITY.md" "$SRC/SOUL.md" "$SRC/VIBES.md" "$DEST/"
echo "Installed Jarvis persona into $DEST"
