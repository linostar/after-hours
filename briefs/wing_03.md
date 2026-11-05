# Wing 3 brief: A Sunday on La Grande Jatte (Seurat)

## Fun pass (feat/fun-polish)
- The rope's wing: the gallery's lure is now pulled from afar. The step-aside parasol at (860, 365) was
  removed, so walking up to the far frame (840, 75) to tilt it leaves footprints the sentry follows from
  the frame straight to the mime; from (760, 380), never near the frame, the rope tilts it (`ROPE`, the
  trick tap, hint unchanged: the frame) and the sentry walks over to straighten it while the mime swaps.
- What the bot taught: the sketch route's old wait at (620, 400) after the pickup lay on the swap
  trail the sentry follows; the mime now waits in the sketch portrait's own parasol shade (690, 219) and
  goes straight to the door.
- Speed route: the doors and the lawn's floor walks dashed; the gallery stays tiptoed. Best 58.42 s
  against half par 55: `speed_target` 60.
- Bot result: 204 plays; 75.38 s, par 110; tricks 1, 3, 6 (the rope), 9 and 11 proved needed; the sketch
  route escapes with the sketch in 77.08 s; the speed route escapes in 58.42 s (target 60).

## Constraints
- Three rooms; 6 guards (the ramp: 3, 5, 6, 8, 9, 12 across the wings); 3 to 6 minutes; every star reachable (bot-proved).
- Every room past the first teaches nothing new in words: each needs one trick, proved by the bot's ablation.
- Gimmick: Seurat's dotted floors keep the mime's footprints (`PRINT_LIFE` 6 s, wiped by a catch); a
  guard who sees them follows the trail. Parasols cast shade: in it a guard cannot see the mime, even in his cone.

## Depth pass (feat/polish-depth)
- Room 0, the lawn: trick **shade**. The east half is a corridor of hedges its guard sweeps to the hall
  door; in the parasol's shade over it a guard cannot see the mime even passing it (shade beats touch),
  so the mime stands there as he turns, both ways.
- Room 1, the hall: trick **hide** (the corridor).
- Room 2, the gallery: trick **lure** (a sentry on the swap spot, the far frame); a parasol gives cover.
- Sketch: inside the gallery's portrait (Mona Lisa), hidden in after the swap.
- What the bot taught: the lawn's second guard by the entrance followed the mime's prints from the
  door, so he walks the south-east lawn (560 to 860, y 400) and follows only the prints left on the way
  out; waiting at the corridor's mouth left the mime where its guard comes, so the mime waits at the
  easel; the way out steps aside into the west parasol's shade. In the gallery the sentry followed the
  prints from the tilted frame to the mime: a parasol now shades the step-aside (860, 365) and one the
  sketch's portrait (680, 215), and the third guard keeps to the back wall (200 to 260, y 215).
- Bot result: 227 plays; 79.53 s, par 115; tricks 1, 3, 6, 10 and 12 proved needed; the sketch route
  escapes with the sketch in 84.23 s.

## History
Re-recorded with guards turning smoothly (step 10): 52 plays; the run takes 60.6 s, par 95 s.
Re-recorded with guards patrolling round the display walls (art pass): 40 plays; the run takes 57.6 s, par 90 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass); the hall guard's waypoints at x 700 (on the right wall's edge) moved to x 730: 57 plays; the run takes 61.8 s, par 95 s.
Re-recorded with the floor props (polish pass): 57 plays; the run takes 61.8 s, par 95 s.
