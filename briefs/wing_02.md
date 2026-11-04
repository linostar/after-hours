# Wing 2 brief: The Great Wave off Kanagawa (Hokusai)

## Depth pass (feat/polish-depth)
- Three rooms, 5 guards. Each room past the print room's crossing needs one trick (bot ablation).
- Room 0, the print room (easel, exit): trick **puddle lure**. A sentry paces before the right door;
  wading through the puddle on the far side splashes, and he comes to look while the mime slips past.
- Room 1, the hall: trick **hide**. One guard walks the back row to the far door and turns back; the
  lower floor is closed off; the mime hides in the portrait as he passes.
- Room 2, the gallery: trick **lure (choose the frame)**. Two guards; a tilt pulls only the nearest in
  earshot, so the frame by the swap guard pulls him off and the other would pull the wrong one.
- Sketch: behind the hall's spare frame (tilting it makes the noise too).

## Constraints
- Three rooms (lengthened from two after the first playtest); 3 to 6 minutes; every star reachable (bot-proved).
- New idea: time. The player waits for the right moment instead of finding a hidden path.
- Gimmick: burst pipes (replaced the tide, which flooded the floor with no visible reason).
  A water pipe runs along the back wall; each burst gushes on its own rhythm, pouring a
  stream onto the floor, and its puddle spreads to full size, then dries back to a damp
  patch while the pipe drips. In a puddle the mime wades at 55% speed and every step
  splashes loudly enough for the nearest guard to come and look; guards wade at 55% too.
  Prussian-blue water and foam drops in the print's style.
- Two guards in the gallery: the first two-guard room.

## Layout
- Room 0, the print room (Hokusai's paper walls, an indigo wainscot): the easel stands by
  the back wall on the right, behind a partition; one guard walks along the front. A burst
  over the crossing to the right door (puddle at (830, 350), every 9 s) and one beside the
  exit (puddle at (150, 450), every 10 s): leaving means timing the pipe or splashing.
- Room 1, the gallery: The Great Wave hangs in the middle. One guard walks the back row
  under the painting; another loops the front between two partitions. A burst beside the
  Great Wave floods the swap spot at full size (puddle at (560, 250), every 12 s) and one before the door back (190, 340).

- Room 1, the hall (new): bursts over the middle of the crossing (560, 330) and before the
  far door (820, 400); two partitions; a
  guard loops the middle, another walks the lower left; a Mona Lisa to hide in.
- The print room has a second guard looping the back half; the gallery's back-row guard
  now loops down to y 330 and back.

## Intended route
Round the partition to the easel; paint while the front guard walks away; through the right
door; wait for the back-row guard to pass the painting, then swap; back through the left
door; out by the lower door when its pipe has stopped gushing.

## Design loop
The first draft passed: the bot found a wait for every leg on its first recording.

## Lengthening pass
Lengthening pass: a hall, a second print-room guard and a longer gallery loop.
1. The hall's loop ran up to x 840 along the back, facing right, so it saw the mime coming
   back in at the right door. The loop was pulled in to x 260 to 700.

## Burst pipes pass
The tide became burst pipes (the developer: "why is there a sea in the museum?"). The pipes
were placed over the old route's wet crossings and the bot passed on its first recording.
1. Bursts straight behind a painting (the hall's Mona Lisa, the Great Wave) made the water
   seem to pour out of the painting, the reading the pipes replaced. They moved to clear
   wall at x 560 (the gallery's puddle grew to radius 90 so it still floods the swap spot).
1. No display wall may stand in water (art pass; `puddles_clear_of_partitions`: every
   puddle at full size 12 off every partition's footprint, and never hidden behind a wall's
   face). The gallery's swap-spot puddle moved to (545, 228) at radius 74, still flooding
   the swap spot (480, 235) but clear of the right wall's top; its west puddle to (175, 340)
   at radius 70; the hall's right wall moved from x 650 to 725, out of the middle puddle
   (whose pipe cannot move left: the portrait hangs there).

## Bot result
`tools/bot.gd --record`: 41 plays; the hall crossing back waits 0.75 s and the exit 7.75 s for its pipe; the run takes 37.7 s, par 85 s.
Re-recorded at a person's painting pace (step 10): 38 plays; the run takes 54.5 s, par 85 s.
Re-recorded with the walls out of the water (art pass): 50 plays; the run takes 57.8 s, par 90 s.
Re-recorded with guards patrolling round the display walls (art pass): 96 plays; the run takes 69.2 s, par 100 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass): 42 plays; the run takes 55.8 s, par 85 s.
Re-recorded with the floor props (polish pass): 55 plays; the run takes 59.15 s, par 90 s.
