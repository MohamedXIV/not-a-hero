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
"$BIN" -b -t 2 --python /tmp/room_minimal.py -- "$(pwd)/public"
cp /tmp/room_minimal.py public/little_nest_blockout.py
cp tools/camera-study/index.html public/index.html
test -s public/little_nest_camera_study.blend
for angle in 70 60 50 40; do test -s "public/little_nest_${angle}deg.png"; done
echo 'CAMERA STUDY SUCCESS - Editable Blender scene and 4 angle renders'
ls -lh public
