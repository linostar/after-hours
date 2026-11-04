# Wing 4 brief: The Starry Night (Van Gogh)

## Constraints
- Four rooms (the ramp: the second half of the museum is longer); 8 guards; 4 to 7 minutes; every star
  reachable (bot-proved).
- Each room past the terrace's crossing needs one trick, proved by the bot's ablation.
- Gimmick: swirling stars sweep searchlights across the floor; a pool reveals the mime once per
  stepping-in, to the first guard within hearing range, who comes to look.

## Depth pass (feat/polish-depth)
- Room 0, the terrace: trick **searchlight call** on the way in (a still pool on the west side: stepping
  in reveals the mime to the gap's sentry, who comes to look), **frame lure** on the way out.
- Room 1, the hall: trick **hide** (the corridor); searchlights roam the walled-off floor.
- Room 2, the observatory (new): trick **lure chain**. Two screens, a sentry in each gap; the frame
  nearest each sentry pulls him (west and middle on the way in, east and middle on the way back).
- Room 3, the gallery: trick **lure** (a sentry on the swap spot, the far frame).
- Sketch: inside the hall's middle portrait.
- Bot result: not recorded yet; run `tools/record_wings.sh` (it records the waits, par time, ghost and sketch waits, then proves every trick needed).

## History
Re-recorded with guards turning smoothly (step 10): 63 plays; the run takes 63 s, par 95 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass): 53 plays; the run takes 60.6 s, par 95 s.
Re-recorded with the floor props (polish pass): 39 plays; the run takes 56.92 s, par 90 s.
