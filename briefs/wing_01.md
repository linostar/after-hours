# Wing 1 brief: Girl with a Pearl Earring (Vermeer), the tutorial

## Fun pass (feat/fun-polish)
- No power yet (the ball unlocks with wing 2); the route and layout are unchanged.
- Speed route (the SPEED challenge): the main route with the doors dashed (a double tap on a door now
  dashes through it). Dashing the gallery's floor walks brings the sentry running (each dashed step is
  a noise) and he catches the mime at the step-aside, so those stay tiptoed. The bot's best is 46.92 s
  (seen, never caught) against half par 45: `speed_target` 50.
- Bot result: 94 plays; 60.63 s, par 90; tricks 2, 5 and 9 proved needed; the sketch route escapes with
  the sketch in 61.95 s; the speed route escapes in 46.92 s (target 50).

## Depth pass (feat/polish-depth)
- Three rooms, 3 guards (the ramp: 3, 5, 6, 8, 9, 12 across the wings). Teach, in order: walk, paint,
  door, then hiding in the hall and tilting in the gallery, each a room's needed trick.
- Room 0, the foyer (safe, no guard; trick-free): the Mona Lisa portrait hides the wing's **sketch**
  (stepping in drops it to the floor below; tap it).
- Room 1, the hall: trick **hide**. A narrow back corridor (walkable y 180 to 240, doors at y 210) its
  guard sweeps from just inside one door to just inside the other; low Delft vitrines wall off the
  lower floor. On the way in the mime hides in the far portrait as he turns at the far door; on the
  way back (he restarts heading straight at the returning mime) it hides there at once and walks out
  behind him.
- Room 2, the gallery: trick **lure**. A sentry paces across the swap spot (his back is never turned
  for the 1.5 s swap); the frame at the far end of the back wall is in his earshot only. Go low round
  the right, tilt it, step aside as he comes, swap while he straightens it.
- What the bot taught: guards now see the mime at once within CLOSE_RANGE in their cone and notice
  one brushing past within TOUCH_RANGE (it slipped past at first: overtaking in dim light, and round
  his back as he turned); the corridor was narrowed so no one passes the guard; a middle-portrait hide
  on the way back proved unneeded and was dropped.
- Bot result (depth pass, with the look round): 94 plays; 60.63 s, par 90; tricks 2, 5 and 9 proved
  needed; the sketch route escapes with the sketch in 61.95 s.
## Constraints
- Three rooms (lengthened from two after the first playtest); 3 to 6 minutes for a first-time player; every star reachable (bot-proved).
- Teach, in order and without words: walk, paint, go through a door, swap, hide, tilt.
- The way out differs from the way in.
- Gimmick: Vermeer's window light, a slanted band of daylight drifting slowly across the
  floor. In it the mime is lit and guards grow suspicious 1.8x as fast; elsewhere the
  gallery is dim (0.6x).

## Layout
- Room 0, the foyer (safe, no guard): the mime comes in by the left door. The glowing easel
  stands in the open; a small Great Wave to tilt and a tall Mona Lisa to step into are
  there to try with nobody watching. A door on the right leads on; the exit is a second,
  lower door on the left wall.
- Room 1, Vermeer's gallery: Pearl Earring hangs on the back wall right of centre. One guard
  walks a wide loop around a low partition; the window's light band sweeps the floor between
  the door and the painting. A Mona Lisa to hide in stands by the right wall, a Grande Jatte
  frame to tilt near the window.

- Room 1, the hall (new in the lengthening pass): the window light sweeps it too; two
  partitions; one guard loops the middle of the room, another paces up and down beside the
  lower partition; a Mona Lisa to hide in by the right wall.
- The gallery (now room 2) has a second guard pacing the right wall and the back row's right
  end.

## Intended route
Paint at the easel; through the right door; wait for the guard to turn the far corner and for
the light to drift away, then swap; back through the left door; out by the lower door.

## Design loop
The first draft passed: the bot found a wait for every leg on its first recording.

## Lengthening pass
Lengthening pass (the first playtest took 67 s against a 3 to 6 minute goal): a hall was
added between the foyer and the gallery, and a second gallery guard.
1. The hall's loop guard started at the bottom left facing up, in view of the left door:
   the mime was seen on arrival from the foyer. The loop was turned to start on the right.
2. Its new start was below the right door, in view of the mime coming back from the
   gallery. The loop now starts in the middle of its bottom leg.

## Bot result
`tools/bot.gd --record`: 45 plays; the hall crossing waits 2 s, the swap 7.5 s; the run takes 39.5 s, par 85 s.
Re-recorded at a person's painting pace (step 10): 41 plays; the run takes 56 s, par 85 s.
Re-recorded with the floor props (polish pass): 43 plays; the run takes 56.7 s, par 85 s.
