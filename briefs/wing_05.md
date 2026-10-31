# Wing 5 brief: The Garden of Earthly Delights (Bosch)

## Constraints
- Three linked rooms, the triptych: Eden, the Garden, Hell. Lengthened with more guards after the first playtest. 3 to 6 minutes; every star
  reachable (bot-proved).
- New idea: distance. The masterpiece is two rooms away, so the run is long and the way
  back passes every hazard again with the original.
- Gimmick: Bosch's creatures roam each room (a giant strawberry, a long-legged bird, a fish
  on legs), each on its own looping path at its own pace. A step within 45 units of one
  startles it (a red ring): it squawks, and the nearest guard within 80% of hearing range
  comes to look.

## Layout
- Room 0, Eden (pale sky walls): the easel by the back wall; one guard paces the front; two
  creatures; the exit low on the left.
- Room 1, the Garden (bright green): no painting to steal, only the passage. Two partitions,
  three creatures, a guard on the back row and one on the front right; a Pearl Earring to
  hide in mid-wall.
- Room 2, Hell (dark red): the triptych hangs right of centre; a guard paces the right of the
  back row beside it, another the front; a partition to wait behind; two creatures.

- Lengthening pass: Eden has a second guard looping its left side; the Garden a third,
  pacing the lower right; Hell's front guard loops the lower floor.

## Intended route
Paint in Eden; cross the Garden between the creatures' loops and the guards' turns; swap in
Hell; come back the same way, now carrying the original past the same creatures, and leave
Eden low on the left.

## Design loop
The first draft passed: the bot found a wait for every leg on its first recording.

## Lengthening pass
Lengthening pass (more guards; the wing already had three rooms):
1. The Garden's third guard first paced at x 500, across the line between its doors: no
   wait got the mime across. It moved to the lower right.
2. Eden's new loop first reached x 760 facing right, in view of the mime coming back in
   (moved in to x 640), then ran through the easel spot (moved to the left side).
3. Even so, the straight line from Eden's right door to the exit crossed both Eden guards'
   beats. The route now goes along the top of the room first (a waypoint at (300, 215)), as
   a player would.

## Bot result
`tools/bot.gd --record`: 42 plays; the doors in wait 4.25 and 4 s; the run takes 39 s, par 90 s (the bot threads the extra guards; a person will be slower).
