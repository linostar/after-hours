# Wing 6 brief: Mona Lisa (Leonardo), the finale

## Fun pass (feat/fun-polish)
- All three powers are available; the recorded route keeps its lures and hides (every earlier trick
  returns, the finale's idea) and uses none, which the NO_POWERS challenge rewards.
- Speed route: the doors dashed. Dashing the salon's floor walks too saved nothing (84.57 s against
  84.50 s). Best 84.50 s against half par 72.5 (five rooms there and back): `speed_target` 85.
- Bot result: 172 plays; 102.73 s, par 145; tricks 1, 4, 6, 9, 12, 16, 20, 23, 26, 29 and 31 proved needed;
  the sketch route escapes with the sketch in 109.62 s; the speed route escapes in 84.50 s (target 85).

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
- What the bot taught: the salon and the antechamber take the terrace's fix (the puddle at (390, 478)
  and the pool at (430, 480), entered from the west, left north-west; the other guards to the west
  wall); gap B's sentry saw the east frame tilted, so it hangs at (880, 75); the salle takes the wing 3
  gallery's parasols and its third guard by the back wall.
- Bot result: 102.73 s, par 145 (the longest wing); tricks 1, 4, 6, 9, 12, 16, 20, 23, 26, 29 and 31
  proved needed; the sketch route escapes with the sketch in 109.62 s.

## History
Re-recorded with guards turning smoothly (step 10): 59 plays; the run takes 61.8 s, par 95 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass); the gallery guard's waypoints at x 700 (on the right wall's corner) moved to x 730: 33 plays; the run takes 55.5 s, par 85 s.
Re-recorded with the floor props (polish pass): 40 plays; the run takes 57.33 s, par 90 s.
