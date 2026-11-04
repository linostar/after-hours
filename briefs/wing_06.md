# Wing 6 brief: Mona Lisa (Leonardo), the finale

## Constraints
- Five rooms, the longest wing; 12 guards; 6 to 9 minutes; every star reachable (bot-proved).
- Its own look: the Louvre after dark (marble and damask walls, gilt trim, the glass case), not wing 4's
  starry wall; every earlier gimmick returns (GimmickMix).
- Each room past the salon's crossing needs one trick, proved by the bot's ablation.

## Depth pass (feat/polish-depth)
- Five rooms, 12 guards; the Louvre after dark (red damask, gilt, marble; no starry sky).
- Room 0, the salon (window light, burst pipes): trick **puddle lure** in, **frame lure** out (the
  print room's gap).
- Room 1, the gallery (burst pipes): trick **hide** (the corridor).
- Room 2, the grande galerie (new; window light): trick **lure chain** (two gaps, a sentry in each, a
  third guard below).
- Room 3, the antechamber (new; searchlights): trick **searchlight call** in, **frame lure** out.
- Room 4, the salle (the Mona Lisa under glass; footprints, searchlights): trick **lure** (a sentry on
  the swap spot, the far frame).
- Sketch: inside the gallery's middle portrait.
- Bot result: not recorded yet; run `tools/record_wings.sh` (it records the waits, par time, ghost and sketch waits, then proves every trick needed).

## History
Re-recorded with guards turning smoothly (step 10): 59 plays; the run takes 61.8 s, par 95 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass); the gallery guard's waypoints at x 700 (on the right wall's corner) moved to x 730: 33 plays; the run takes 55.5 s, par 85 s.
Re-recorded with the floor props (polish pass): 40 plays; the run takes 57.33 s, par 90 s.
