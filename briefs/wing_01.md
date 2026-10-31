# Wing 1 brief: Girl with a Pearl Earring (Vermeer), the tutorial

## Constraints
- Two rooms; 3 to 6 minutes for a first-time player; every star reachable (bot-proved).
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

## Intended route
Paint at the easel; through the right door; wait for the guard to turn the far corner and for
the light to drift away, then swap; back through the left door; out by the lower door.

## Bot result
`tools/bot.gd --record`: 12 plays; the swap needs a 1.75 s wait for the guard's turn; the
run takes 22.3 s, par 65 s (bot time plus 4 s per ghost stroke, x1.25).
