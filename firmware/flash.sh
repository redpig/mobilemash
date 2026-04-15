#!/bin/sh
# Build and flash MobileMash firmware to ESP32 via PlatformIO.
# Usage: ./flash.sh          # build and upload
#        ./flash.sh build    # build only (no upload)
set -e

cd "$(dirname "$0")"

if [ "${1:-}" = "build" ]; then
    python3 -m platformio run
else
    python3 -m platformio run --target upload
fi
