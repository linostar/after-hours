# After Hours

A silent mime sneaks into a museum after dark, paints a forgery of each of six public-domain
masterpieces, swaps it for the original and escapes. Jam entry for Jamference: AI Game Jam Hack 3
(theme "Great Works of Art", restriction "No Text"). Godot 4.7.1, web (desktop and mobile, landscape).

**Play:** <!-- TODO: itch.io page link -->

## Controls

- **Touch or mouse:** tap the floor to walk; tap the easel to paint, then trace the glowing strokes; tap a
  frame to tilt it, a portrait to hide in it, the masterpiece to swap it, a door to go through.
- **Keyboard:** WASD or arrows to move, `E` to interact, `Space` to pause; menus work with arrows and Enter.
- **Settings (gear / pause):** music, sound, motion effects, Assist (one press paints a Good forgery).

## Development

Needs Godot 4.7.1 (`GODOT` overrides `/Applications/Godot.app/Contents/MacOS/Godot`), Python 3, Node and
Google Chrome. Run from the repo root.

- One-time setup: `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm --prefix tools ci`
- Validate (import, asset checks, project check, gameplay tests, bot replays): `tools/validate.sh`
- Play one wing directly: `"$GODOT" --path afterhours -- --wing N`
- Re-record every wing's bot run: `tools/record_wings.sh`
- Regenerate audio: `python3 tools/sfx.py`, `python3 tools/music.py`, `python3 tools/voices.py`
  (VoiceStudio running), then `"$GODOT" --headless --path afterhours --import`
- Release build (validate, web export, smoke test, zip): `tools/build_web.sh` → `build/afterhours.zip`
- Record footage: `"$GODOT" --path afterhours --fixed-fps 60 --write-movie out.avi --script "$PWD/tools/bot.gd"`
  (sound plays while recording; the window must stay visible or frames freeze)

Itch page text and upload settings: `SUBMISSION.md`; cover and screenshots: `submission/`.
