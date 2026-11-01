# Wing 2 brief: The Great Wave off Kanagawa (Hokusai)

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

## Bot result
`tools/bot.gd --record`: 41 plays; the hall crossing back waits 0.75 s and the exit 7.75 s for its pipe; the run takes 37.7 s, par 85 s.
Re-recorded at a person's painting pace (step 10): 38 plays; the run takes 54.5 s, par 85 s.
