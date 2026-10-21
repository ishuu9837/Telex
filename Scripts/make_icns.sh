#!/bin/bash
# Rebuilds Assets/AppIcon.icns from Assets/AppIcon.iconset using Apple's iconutil (macOS only).
set -euo pipefail
cd "$(dirname "$0")/.."
iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
echo "Created Assets/AppIcon.icns"
