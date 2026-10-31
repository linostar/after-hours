# Wing 4 brief: The Starry Night (Van Gogh)

## Constraints
- Two rooms; 3 to 6 minutes; every star reachable (bot-proved).
- New idea: the room itself watches. Light is no longer a slow drift (wing 1) but moving
  hazards to dodge in the dark.
- Gimmick: swirling searchlights. Night lies over the floor (guards notice the mime at half
  speed); pools of light circle on their own orbits, neighbours turning opposite ways like
  the painting's swirls. In a pool the mime is lit (2.5x) and revealed: the first guard to
  look is shown where it stands and comes to check, once each time it steps in.
- The forgery's moon is one loose ring (the slice's playtest scored its spiral 0.19).

## Layout
- Room 0, the night terrace (deep blue walls, still stars painted on the wall): the easel by
  the back wall; two pools circling the floor between it and the door; one guard looping the
  room, a partition by the entrance to wait behind.
- Room 1, the gallery: The Starry Night hangs in the middle; three pools; one guard paces the
  right half of the back row, another the front row; a partition breaks the front guard's
  view.

## Intended route
Wait behind the partition for a gap in the pools and the guard's loop; paint; through the
right door; swap between the pools' passes; back and out low on the left.

## Design loop
The first draft passed: the bot found a wait for every leg on its first recording.

## Bot result
`tools/bot.gd --record`: 40 plays; the easel waits 8 s for the pools and the guard; the run
takes 28.3 s, par 80 s.
