#!/usr/bin/env bash
# Produce the existing Godot game's playable non-threaded HTML5 build.
# Matches the engine/export-template version already verified in CI.
set -euo pipefail

version="4.7.2"
engine_dir="${TMPDIR:-/tmp}/not-a-hero-godot"
template_dir="${HOME}/.local/share/godot/export_templates/${version}.stable"
mkdir -p "$engine_dir" "$template_dir"

curl -fLsS --retry 3 -o "$engine_dir/godot.zip" \
  "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip"
unzip -q "$engine_dir/godot.zip" -d "$engine_dir"
chmod +x "$engine_dir/Godot_v${version}-stable_linux.x86_64"

curl -fLsS --retry 3 -o "$engine_dir/templates.tpz" \
  "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_export_templates.tpz"
unzip -q -j "$engine_dir/templates.tpz" 'templates/web*' -d "$template_dir"
rm -f "$engine_dir/templates.tpz" "$engine_dir/godot.zip"

engine="$engine_dir/Godot_v${version}-stable_linux.x86_64"
"$engine" --headless --path godot --editor --import --quit
mkdir -p godot/build/web
"$engine" --headless --path godot --export-release Web "$(pwd)/godot/build/web/index.html"
test -s godot/build/web/index.html
test -s godot/build/web/index.wasm
test -s godot/build/web/index.pck
echo "PASS: Not a Hero 2D playable Web build exported from current source"
