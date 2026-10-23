#!/usr/bin/env bash
set -euo pipefail
VER=5.2.3
ARCHIVE="blender-${VER}-linux-x64.tar.xz"
BIN_DIR="/tmp/nah-blender"
mkdir -p "$BIN_DIR" public
echo "Downloading official Blender ${VER} for camera-only blockout..."
curl --fail --location --retry 3 --connect-timeout 25 -o "$BIN_DIR/$ARCHIVE" "https://mirror.blender.org/release/Blender5.2/$ARCHIVE"
tar -xJf "$BIN_DIR/$ARCHIVE" -C "$BIN_DIR"
BIN="$BIN_DIR/blender-${VER}-linux-x64/blender"
"$BIN" --version | head -3
base64 -d tools/camera-study/room_minimal.py.gz.b64 | gzip -dc > /tmp/room_minimal.py
# The original camera proof looked diamond/isometric-like because it used
# -137 degrees of horizontal azimuth. For our 2D, axis-aligned gameplay,
# the camera must look directly from the foreground towards the rear wall.
# This retains depth/height but no longer rotates the room into a diamond.
python3 - <<'PY'
from pathlib import Path
path = Path("/tmp/room_minimal.py")
source = path.read_text()
old = "az=math.radians(-137)"
assert source.count(old) == 1, "Unexpected Blender script; do not silently emit wrong cameras"
source = source.replace(old, "az=math.radians(-90)")
path.write_text(source)
print("Oblique-feeling 2D camera correction: fixed azimuth -90°, no diamond rotation")
PY
"$BIN" -b -t 2 --python /tmp/room_minimal.py -- "$(pwd)/public"
cp /tmp/room_minimal.py public/little_nest_blockout.py
cp tools/camera-study/index.html public/index.html
test -s public/little_nest_camera_study.blend
for angle in 70 60 50 40; do test -s "public/little_nest_${angle}deg.png"; done
echo 'CAMERA STUDY SUCCESS - Editable Blender scene and 4 angle renders'
ls -lh public
