# Wing 6 brief: Mona Lisa (Leonardo), the finale

## Constraints
- Three rooms (lengthened from two after the first playtest); 3 to 6 minutes; every star reachable (bot-proved).
- New idea: everything at once. Every earlier wing's gimmick returns, two per room in the
  salon and three in the Salle; the Mona Lisa hangs under glass (a sheen and a glint).
- Gimmick: GimmickMix, the earlier gimmicks combined: light multiplies (any shade still
  hides, the night halves a window's light), slowing multiplies, the loudest noise wins, the
  first clue is shown.

## Layout
- Room 0, the salon (Louvre browns): Vermeer's window light drifts across the floor and
  wing 2's burst pipes pour onto it; the easel stands left of centre beside a partition; a
  guard paces the front, another walks up and down the middle of the room.
- Room 1, the Salle des États: the Mona Lisa under glass in the middle of the back wall.
  Seurat's footprints (no parasol by the painting: the swap must be timed), Van Gogh's
  searchlights on the floor and a Bosch strawberry roaming the front. Three guards: one
  walks the back row from the right towards the painting, one the front row, one paces the
  right wall.

## Design loop (bot-found fixes)
1. First draft: the second salon guard's beat started 92 units from the easel, so the mime
   was seen as it finished painting. The easel moved left and the beat right.
2. Second draft: that beat ended above the door back from the Salle, so the returning mime
   was seen on arrival. The guard now walks up and down the middle of the salon.
3. Third draft: the bot won in 6 plays with no waits, too easy for a finale: a parasol
   shaded the swap and the back-row guard started walking away. The parasol went and the
   guard now starts at the right, walking towards the painting.

## Lengthening pass
Lengthening pass: a middle gallery and more guards.
4. The grand gallery's second guard first paced up and down at x 500, facing up across the
   line between its doors: no wait got the mime across. It now walks the bottom wall.

## Burst pipes pass
The tide in the salon and the grand gallery became burst pipes (wing 2's gimmick changed).
1. The salon's first puddle sat at (660, 330), on the line from its right door to the
   exit, next to the third guard's beat: wading slowly there on the way out kept the mime
   in that guard's view, and no wait got the last leg through. It moved to (480, 400).

## Bot result
`tools/bot.gd --record`: 77 plays; the doors in wait 1 and 4.5 s, the swap 8 s and the way back 4 s; the run takes 46.6 s, par 100 s.
