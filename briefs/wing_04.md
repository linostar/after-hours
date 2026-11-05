# Wing 4 brief: The Starry Night (Van Gogh)

## Fun pass (feat/fun-polish)
- The box's wing: the hall's corridor has no portrait to hide in on the main route any more. The far
  portrait (PortraitB, (820, 105)) was removed and the corridor guard now restarts at x 300 heading for
  the far door (was 500), so the mime always has room behind him. On the way in the mime follows him
  to (600, 210) and mimes the box there as he turns at the far door; he walks back past it and the mime
  steps out behind him. On the way back he is coming straight at the returning mime, too close for any
  portrait: it walks to (700, 210) and boxes at once, lets him pass to the far door and out of sight,
  and leaves by the near door. Both box taps are trick taps; the hints are the two floor spots. The
  middle portrait (PortraitA) stays: the sketch route hides in it on the way in, as he passes.
- What the bot taught: the box opens by itself after `BOX_TIME` 6 s, so the earliest box (greedy)
  opened before the guard had even turned; the recorder now retries a leg later when the next leg
  cannot get through. The way in boxes 6 s after reaching the spot and steps out 3.75 s later; the
  sketch route stays in PortraitA about 13 s.
- Speed route: the doors and the terrace's floor walks dashed, the boxes kept. Best 71.07 s against half
  par 70: `speed_target` 75.
- Bot result: 521 plays (the box search); 97.48 s, par 140; tricks 1, 5 (box), 7, 10, 14, 18, 21, 25 (box)
  and 27 proved needed; the sketch route escapes with the sketch in 99.83 s; the speed route escapes in
  71.07 s (target 75).

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
- What the bot taught: the terrace's pool by the gap brought the sentry straight onto the mime, so the
  pool lies far from the gap (430, 480), entered from the west and left north-west (320, 300) out of
  his line and his look round; the easel stands at (200, 440) and the second guard watches the exit
  approach from the north-west (x 110). The sketch route goes back into the hall's middle portrait
  after the pickup.
- Bot result: 156 plays; 89.52 s, par 130; tricks 1, 4, 6, 9, 13, 17, 20, 23 and 25 proved needed; the
  sketch route escapes with the sketch in 96.40 s.

## History
Re-recorded with guards turning smoothly (step 10): 63 plays; the run takes 63 s, par 95 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass): 53 plays; the run takes 60.6 s, par 95 s.
Re-recorded with the floor props (polish pass): 39 plays; the run takes 56.92 s, par 90 s.
