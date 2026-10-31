#!/usr/bin/env bash
# Re-records the playtest bot's run (waits, par time, ghost replay) for every wing and the
# slice fixture wing (tools/bot.gd --record), one after another; stops at the first wing
# the bot cannot beat. Env: GODOT (Godot binary).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
wings=(afterhours/data/wings/wing_*.tres afterhours/scenes/test/slice_wing.tres)
for wing in "${wings[@]}"; do
  "$GODOT" --headless --path afterhours --fixed-fps 60 --script "$PWD/tools/bot.gd" -- --record "res://${wing#afterhours/}" 2>&1 | grep -E "^bot: (recorded|FAILED)"
done
