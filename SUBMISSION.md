# After Hours: itch.io submission

The page text for the itch.io page and the jam entry for
**Jamference: AI Game Jam Hack 3** (https://itch.io/jam/jamference-ai-game-jam-hack-3).
Everything between the two rules below is the public page; paste it as is.

## Upload settings

- **Title:** After Hours
- **Short description (tagline):** A silent mime sneaks into a museum after dark, paints a forgery of each masterpiece and swaps it for the original.
- **Kind of project:** HTML
- **Upload:** `build/afterhours.zip` (rebuild with `tools/build_web.sh` first), tick "This file will be played in the browser".
- **Embed options:** viewport 960 x 540, fullscreen button on, "SharedArrayBuffer support" off. Tick "Mobile friendly" and choose landscape orientation.
- **Classification:** Game. Genre: Puzzle. Tags: stealth, heist, art, museum, painting, mime, no-text, mobile, touch, godot.
- **Cover image:** `submission/cover.png` (630 x 500).
- **Screenshots:** `submission/1-title.png` to `submission/12-unlock.png`, in that order (1920 x 1080, landscape).
- **Trailer / gameplay video:** `build/afterhours_demo.mp4` (27.8 s; itch takes a YouTube or Vimeo link, so upload it there first, or attach it to the jam post).
- **Jam:** submit the page to the jam; it uses the optional theme "Great Works of Art" and the mandatory restriction "No Text".

---

# After Hours

**The museum is closed. The guards are bored. The mime has a brush.**

A silent mime slips into a museum after dark with one plan: paint a forgery of each of six great masterpieces, hang the fake where the original was, and walk out with the real thing before anyone notices.

Each wing of the museum is three rooms and one painting:

1. **Girl with a Pearl Earring** (Vermeer): a shaft of window light sweeps the room.
2. **The Great Wave** (Hokusai): burst pipes gush in rhythm, and the puddles they leave are slow and loud underfoot.
3. **A Sunday on La Grande Jatte** (Seurat): the dotted lawn keeps your footprints, and the guards follow them; parasols give shade.
4. **The Starry Night** (Van Gogh): swirling stars sweep across the floor like searchlights.
5. **The Garden of Earthly Delights** (Bosch): a triptych of three long rooms; the distance is the challenge.
6. **Mona Lisa** (Leonardo): the finale under glass, where every earlier trick returns.

How you play:

- **Tap the floor** to tiptoe there. Plan your route around the guards' vision cones.
- **Paint the forgery** at the easel by tracing the painting's own strokes: Van Gogh's swirls, Seurat's dots, Hokusai's sweeping curves. A Perfect copy is never noticed, a Good one survives one look, a Sloppy one gets a guard searching.
- **Tilt a frame** to make a noise and pull a guard away.
- **Hide inside a portrait** and watch the room through the painting's own style. Guards pass you by, unless they saw you step in.
- **Swap** the fake for the original and get out. Caught? You get tossed back to the room's entrance (still holding the painting).

Each wing gives up to three stars: swap done, never seen, under par time. Stolen originals hang in your hideout, gold-framed for three stars, and come alive in their painting's style; from there you can watch a replay of a perfect run. A see-through "ghost" mime shows the way the first time through each wing.

The guards are a bumbling pair (and later trio) with their own voices. They patrol, hear noises, straighten crooked frames, inspect suspicious paintings, search and chase. They run on classic game AI, not a language model, and play out the same way every time, so a plan that works once works again.

- **Controls:** touch or mouse (tap and drag). Keyboard: WASD or arrows to move, E to interact, Space to pause, and every menu works with arrow keys and Enter.
- **Settings:** music, sound, reduced motion (no screen shake, a plain fade instead of the iris wipe) and Assist (one press paints a Good forgery).
- Plays in desktop and mobile browsers, in landscape. Your progress is saved in your browser.

## The restriction: No Text

There is no written word anywhere in the game: no menus, labels, tutorials, numbers or error messages. Scores are stars, par time is a clock icon, the tutorial is the ghost mime, and settings are icons. The only exception is the title logo, which the jam allows. The project ships no fonts at all, and a checker fails the build if any text node, font or drawn string appears in code or scenes. The guards talk, but nothing they say is needed: every line has an icon and a sound effect, so the game plays fully muted or in any language.

## The theme: Great Works of Art

Six public-domain masterpieces are the levels, the puzzles and the reward. Each wing's floor, music, hazards and forgery strokes come from its painting, and each painting has its own style shader used on the wall, inside the hiding view, on the forgery canvas and in the hideout.

## Team

- **linostar** (solo developer): game direction and every design decision (concept, scope, mechanics, look and feel), playtesting, reviewing, and publishing.
- **Claude** (Anthropic's AI, through Claude Code): built the game to that direction, writing all the code, art, sound, music, level design and the guards' lines listed below.

## How AI was used

After Hours was made with Claude (Anthropic), used through Claude Code, and the guards' voices were rendered locally with the OmniVoice text-to-speech model (k2-fsa/OmniVoice), run through VoiceStudio, an open-source local voice app. There are no asset packs and no other AI tools. Apart from the eleven public-domain paintings (six masterpieces and five decoys) and the engine, everything was made for this jam:

- **Code:** about 7,100 lines of GDScript in Godot 4.7.1. Game rules (vision and suspicion, the guards' brain, forgery grading, stars, saves) are pure functions, separate from the scenes, so every rule can be tested.
- **Art as code:** all 53 sprites, props, icons, floors and the logo are hand-written SVG (the mime and the guards are jointed rigs with a walk cycle), and 16 shaders give each painting its style: Vermeer's window light, Hokusai's woodblock bands, Seurat's breathing dots, Van Gogh's swirling strokes, Bosch's varnish, Leonardo's sfumato smoke.
- **Sound:** all 35 sound effects are synthesised by a Python synthesiser Claude wrote. Nothing is sampled.
- **Music:** eight loops composed around one original caper motif and rendered by a Python synthesiser Claude wrote: a jazzy caper for the lobby and a loop for each wing in its painting's era (harpsichord for Vermeer, koto for Hokusai, music-hall accordion for Seurat, swirling strings for Van Gogh, shawm and tabor for Bosch, lute for Leonardo).
- **Voices:** Claude wrote the guards' lines and described two voices (a weary watchman and a jumpy rookie); OmniVoice designed the voices from those descriptions (no cloned voices) and rendered the 32 lines. A script checks each line by transcribing it back with VoiceStudio's built-in speech recogniser, retrying any take that doesn't say its text.
- **Level design with a playtest bot:** Claude designed each wing from a written brief, and a bot plays it through simulated touches like a player would, painting included. When it can't get through unseen, the log shows who spotted it where; the layout is fixed and the bot runs again. Every wing is proven beatable with all three stars, and the bot's runs become the ghost-mime tutorial and the hideout replays.
- **Guard AI (no language model):** a utility-scoring brain picks each guard's intent (patrol, investigate, straighten, inspect, search, chase) from what it sees and hears. It's deterministic and runs offline.
- **Quality:** 111 automated gameplay tests (about 1,650 checks), the playtest bot on every wing, a project checker that enforces the No Text rule, touch-first input and the no-flashing rule (with 18 test projects proving each check fires), and browser tests of the web build on desktop and an emulated phone. The cover, screenshots and gameplay video were captured from the real game by scripts.

## Content

Mild cartoon theft, no flashing, no gore. Alarm and danger effects pulse slowly (under 2 Hz), and Reduce Motion removes the screen shake.

## Credits

- Made by linostar with Claude (Anthropic).
- Paintings (all public domain, from Wikimedia Commons):
  - Johannes Vermeer, *Girl with a Pearl Earring*, c. 1665
  - Katsushika Hokusai, *The Great Wave off Kanagawa*, c. 1830-1832
  - Georges Seurat, *A Sunday on La Grande Jatte*, 1884-1886
  - Vincent van Gogh, *The Starry Night*, 1889
  - Hieronymus Bosch, *The Garden of Earthly Delights*, c. 1490-1510
  - Leonardo da Vinci, *Mona Lisa*, c. 1503-1519
  - Decoys on the walls: John Singer Sargent, *Madame X*, 1883-1884; Vincent van Gogh, *Self-Portrait*, 1889; Raphael, *Portrait of Baldassare Castiglione*, c. 1514-1515; J. M. W. Turner, *The Fighting Temeraire*, 1839; Claude Monet, *Impression, Sunrise*, 1872
- Guard voices: rendered with OmniVoice (k2-fsa) in VoiceStudio (https://github.com/debpalash/VoiceStudio), from voice designs written by Claude.
- No fonts are used anywhere in the game.
- Engine: Godot Engine 4.7.1 (MIT license), https://godotengine.org.

---

## Before you press publish

- Upload `build/afterhours.zip` from a fresh `tools/build_web.sh` run on the final commit.
- Play the uploaded page in a private window on desktop: the game is framed with no odd letterbox bars, fullscreen works, and the music starts by your first click.
- On a real **iPhone (Safari)** and a real **Android phone (Chrome)**, play the itch page through wing 1 (jam plan, criterion 40):
  - The sound is on by your first tap (the iPhone's silent switch can mute it).
  - Turning the phone to portrait shows the rotate-phone icon and pauses; landscape resumes.
  - Tapping, tracing the forgery and the pause button all follow your finger; pull-to-refresh, double-tap zoom, text selection and long-press menus never trigger.
- Submit to the jam before **2026-11-06 08:00** (the jam page gives no timezone; ask on the jam's Discord if unsure). During rating week only bug fixes are allowed, and a post-jam version must be labelled as such.
