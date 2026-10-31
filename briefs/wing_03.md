# Wing 3 brief: A Sunday on La Grande Jatte (Seurat)

## Constraints
- Three rooms (lengthened from two after the first playtest); 3 to 6 minutes; every star reachable (bot-proved).
- New idea: the mime leaves traces. Guards are no longer only eyes and ears; they read the
  ground.
- Gimmick: a dotted lawn under parasols. Every 26 units the walking mime leaves footprints
  in the paint dots, fading after 14 s; a guard who sees a print walks to the newest one it
  sees, then the next, and so follows the trail. Under a parasol the mime is in shade (guards
  cannot see it) and the grass keeps no prints.

## Layout
- Room 0, the island lawn: the easel stands in the open between two parasols; one guard
  walks a wide loop. A parasol by the path lets the mime wait unseen; prints across the
  open lawn tell on it.
- Room 1, the gallery: La Grande Jatte hangs over a parasol, so the swap itself is in shade,
  but the prints leading to it are not. A guard paces the right half of the back row, a
  second loops the lower right; a second parasol shades the way back to the door.

## Design loop (bot-found fixes)
1. First draft: the back-row guard paced the whole width and crossed the way back to the
   door every time; the bot found no wait that got leg 3 through. Its beat was cut to the
   right half.
2. Second draft: still no way back. The log showed the lawn guard's route started beside the
   right door, facing it, so the mime coming back into room 0 was seen on arrival (guards
   restart their routes when the mime enters a room). The route now starts at the far left.

## Lengthening pass
Lengthening pass: a hall, a second lawn guard and a longer gallery loop. The bot found a
way through on the first recording.

## Bot result
`tools/bot.gd --record`: the easel waits 5.75 s, the hall crossing 5.75 s and the way back 4 s; the run takes 45 s, par 100 s.
