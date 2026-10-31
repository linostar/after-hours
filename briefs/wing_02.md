# Wing 2 brief: The Great Wave off Kanagawa (Hokusai)

## Constraints
- Three rooms (lengthened from two after the first playtest); 3 to 6 minutes; every star reachable (bot-proved).
- New idea: time. The player waits for the right moment instead of finding a hidden path.
- Gimmick: the tide. The sea floods the front of each room and draws back in a steady
  rhythm; on wet floor the mime wades at 55% speed and every step splashes loudly enough
  for the nearest guard to come and look. Guards wade unhindered.
- Two guards in the gallery: the first two-guard room.

## Layout
- Room 0, the print room (Hokusai's paper walls, an indigo wainscot): the easel stands by
  the back wall on the right, behind a partition; one guard walks the waterline along the
  front. The tide floods to y 360 every 10 s. The exit, low on the left wall, is in the
  surf: leaving means timing the tide or splashing.
- Room 1, the gallery: The Great Wave hangs in the middle. One guard walks the back row
  under the painting; another loops the flooded front between two partitions. The tide
  reaches y 300 at its height, so a hurried swap at high tide wades.

- Room 1, the hall (new): flooded by its own tide (to y 330 every 9 s); two partitions; a
  guard loops the middle, another walks the lower left; a Mona Lisa to hide in.
- The print room has a second guard looping the back half; the gallery's back-row guard
  now loops down to y 330 and back.

## Intended route
Round the partition to the easel; paint while the front guard walks away; through the right
door; wait for the back-row guard to pass the painting, then swap; back through the left
door; out by the lower door when the tide has drawn back.

## Design loop
The first draft passed: the bot found a wait for every leg on its first recording.

## Lengthening pass
Lengthening pass: a hall, a second print-room guard and a longer gallery loop.
1. The hall's loop ran up to x 840 along the back, facing right, so it saw the mime coming
   back in at the right door. The loop was pulled in to x 260 to 700.

## Bot result
`tools/bot.gd --record`: 58 plays; the swap waits 0.75 s, the hall crossing back 4.25 s and the exit 7.75 s for the tide; the run takes 42 s, par 90 s.
