# Wing 3 brief: A Sunday on La Grande Jatte (Seurat)

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
- Bot result: not recorded yet; run `tools/record_wings.sh` (it records the waits, par time, ghost and sketch waits, then proves every trick needed).

## History
Re-recorded with guards turning smoothly (step 10): 52 plays; the run takes 60.6 s, par 95 s.
Re-recorded with guards patrolling round the display walls (art pass): 40 plays; the run takes 57.6 s, par 90 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass); the hall guard's waypoints at x 700 (on the right wall's edge) moved to x 730: 57 plays; the run takes 61.8 s, par 95 s.
Re-recorded with the floor props (polish pass): 57 plays; the run takes 61.8 s, par 95 s.
