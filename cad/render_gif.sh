#!/bin/sh
#
# Render assembly_preview.scad to an animated GIF.
# Requires: openscad, xvfb-run, imagemagick (magick)
#
# Usage: ./render_gif.sh [frames] [output.gif]
#   frames   — number of frames (default: 36)
#   output   — output file (default: assembly_preview.gif)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAD_FILE="$SCRIPT_DIR/assembly_preview.scad"
FRAMES="${1:-36}"
OUTPUT="${2:-$SCRIPT_DIR/assembly_preview.gif}"
FRAME_DIR="$(mktemp -d)"
IMG_SIZE="800,600"
CAMERA="0,0,0,55,0,0,200"
COLORSCHEME="Starnight"
DELAY=8  # hundredths of a second between frames

cleanup() { rm -rf "$FRAME_DIR"; }
trap cleanup EXIT

echo "Rendering $FRAMES frames from $SCAD_FILE ..."

for i in $(seq 0 $((FRAMES - 1))); do
    t=$(echo "scale=6; $i/$FRAMES" | bc)
    fn=$(printf "frame%05d.png" "$i")
    LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a \
        openscad -D "\$t=$t" \
        --imgsize "$IMG_SIZE" \
        --camera "$CAMERA" \
        --colorscheme "$COLORSCHEME" \
        -o "$FRAME_DIR/$fn" \
        "$SCAD_FILE" 2>/dev/null
    printf "\r  frame %d/%d" $((i + 1)) "$FRAMES"
done
echo ""

echo "Assembling GIF ..."
magick -delay "$DELAY" -loop 0 "$FRAME_DIR"/frame*.png "$OUTPUT"

echo "Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
