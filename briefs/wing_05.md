# Wing 5 brief: The Garden of Earthly Delights (Bosch)

## Depth pass (feat/polish-depth)
- Four rooms: an antechamber, then the triptych's three panels (Eden, the Garden, Hell); 9 guards.
- Room 0, the antechamber (new): trick **frame lure** both ways at its gap's sentry.
- Room 1, Eden: trick **hide** (the corridor).
- Room 2, the Garden: trick **choose the frame**. The left frame pulls the guard by the back wall, the
  next one the gap's sentry; on the way back the east frame pulls the sentry clear of the third guard.
- Room 3, Hell: trick **lure** (a sentry on the swap spot, the far frame).
- Sketch: inside the Garden's portrait, on the way back.
- Bot result: not recorded yet; run `tools/record_wings.sh` (it records the waits, par time, ghost and sketch waits, then proves every trick needed).
## Constraints
- Three linked rooms, the triptych: Eden, the Garden, Hell. Lengthened with more guards after the first playtest. 3 to 6 minutes; every star
  reachable (bot-proved).
- New idea: distance. The masterpiece is two rooms away, so the run is long and the way
  back passes every hazard again with the original.
- Gimmick: none since step 9: the distance itself (three rooms each way) is the challenge.
  Bosch's creatures roamed each room until the developer's playtest found them ugly and
  unrealistic; they were removed.

## Layout
- Room 0, Eden (pale sky walls): the easel by the back wall; one guard paces the front; the exit low on the left.
- Room 1, the Garden (bright green): no painting to steal, only the passage. Two partitions, a guard on the back row and one on the front right; a Pearl Earring to
  hide in mid-wall.
- Room 2, Hell (dark red): the triptych hangs right of centre; a guard paces the right of the
  back row beside it, another the front; a partition to wait behind.

- Lengthening pass: Eden has a second guard looping its left side; the Garden a third,
  pacing the lower right; Hell's front guard loops the lower floor.

## Intended route
Paint in Eden; cross the Garden between the guards' turns; swap in
Hell; come back the same way, now carrying the original past the same guards, and leave
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
4. The Garden's third guard paced north up x 840 with the door from Hell's arrival point in
   its cone (the layout rule above): the old run escaped only on timing, and when the walls'
   clearance changed the timing (art pass) no wait got the mime in unseen. It now paces east
   and west along y 420 (x 760 to 880), the arrival point never within 41 degrees of its view.

## Bot result
`tools/bot.gd --record`: 42 plays; the doors in wait 4.25 and 4 s; the run takes 39 s, par 90 s (the bot threads the extra guards; a person will be slower).
Re-recorded without the creatures (step 9): 8 plays; the run takes 30.55 s, par 80 s.
Re-recorded at a person's painting pace (step 10): 8 plays; the run takes 50.6 s, par 80 s.
Re-recorded with every walker keeping a body's width off the display walls (art pass), the Garden's third guard pacing sideways: 36 plays; the run takes 57.8 s, par 90 s.
Re-recorded with the floor props (polish pass): 36 plays; the run takes 57.75 s, par 90 s.
