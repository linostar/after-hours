# Wing 5 brief: The Garden of Earthly Delights (Bosch)

## Constraints
- Three linked rooms, the triptych: Eden, the Garden, Hell. 3 to 6 minutes; every star
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

## Intended route
Paint in Eden; cross the Garden between the creatures' loops and the guards' turns; swap in
Hell; come back the same way, now carrying the original past the same creatures, and leave
Eden low on the left.

## Design loop
The first draft passed: the bot found a wait for every leg on its first recording.

## Bot result
`tools/bot.gd --record`: 50 plays; the first door waits 4.25 s and the Garden crossing 4 s
for the creatures and guards, the exit 2.25 s; the run takes 40.6 s, par 95 s.
