# Redraw the characters with jointed limbs, restyle every gimmick effect, and show the traced painting in the grade badge

## Goal
Raise the Polish rating: the mime, guards and ghost mime get a professional redraw with elbows and knees that bend as
they walk; every wing's moving effects (wing 2's burst pipes, leaks and puddles first, then window light, footprints
and parasols, searchlights and the Mona Lisa glass) are redrawn in their wing painting's own art style; and the grade
badge after tracing shows the painting just traced, not a generic landscape.

## Acceptance Criteria
1. Each limb of the mime, the guards and the ghost mime has two parts (upper arm and forearm with a gloved or bare hand; thigh and shin with a shoe) joined at a visible elbow or knee, drawn as SVG parts on CharacterRig.
2. While walking, knees and elbows bend with the walk cycle in every view (front, back, side, mirrored left), and at rest the limbs settle straight; the bend follows phase and stride, so the timing of the stepped signal and footfalls is unchanged.
3. The front, back and side bodies of the mime and the guard are redrawn with shading, outlines and costume detail (the mime's striped shirt and white face; the guard's cap, badge and belt) and read clearly at the in-game size on the 960x540 base viewport.
4. The characters' feet, collision, navigation, hiding and catch behaviour, and every wing's recorded bot route, are unchanged: feet_at stays the ground anchor and the bot replays still pass.
5. Wing 2's water is drawn as a Hokusai woodblock print: an outlined iron pipe with flanges, brackets and a split, curling burst; streams with claw-shaped foam curls; drips; outlined puddles in flat Prussian blue with foam curls at the rim and splash crests. The three draw layers (pipe at z -10, puddles on the floor, falling water at z -7) and the gimmick's rules (SLOW, LOUD, DAMP, beats, broken-pipe reporting) are unchanged.
6. Wing 1's window light, wing 3's footprints and parasols, wing 4's searchlights and wing 6's Mona Lisa glass are each redrawn in their painting's style (Vermeer soft daylight and leaded window, Seurat pointillist dots, Van Gogh swirling brushwork, sfumato glass glare), with their gameplay values (LIT, DIM, PRINT_LIFE, light radii, clue rules) unchanged.
7. Every repeating animation added or changed (limb motion apart, which follows walking) stays under 2 Hz and is pinned in _test_no_flash_rates, and Reduce Motion stills any purely decorative motion added.
8. When a fake is graded, the grade badge shows the painting that was just traced (Paintings.SCANS of the canvas's painting, through Paintings.style) inside a frame, keeping each grade's marker: tilted for Sloppy, plain gold frame for Good, gold frame with rays and a star for Perfect; the generic landscape is removed from the grade art.
9. An unknown painting at grading is reported (push_error with context and the error badge) and the badge still shows its grade frame.
10. The project still contains no text nodes, fonts or numerals; tools/validate.sh passes with zero errors and warnings, and all tests in tools/test_gameplay.gd pass, with the rig tests updated for the jointed limbs and a test checking the badge picture matches the traced painting in every wing.

## Approach
Characters: extend CharacterRig so each arm and leg is an upper Sprite2D with a child lower Sprite2D at the elbow or knee; _pose adds a bend from phase and stride (knee bends on the swing-forward half, elbow slightly bent always and more at the swing). New SVG parts replace mime_arm/mime_leg/guard_arm/guard_leg, the six body SVGs are redrawn, and rig_mime.tscn and rig_guard.tscn get the new textures and joint exports. Effects: keep each gimmick's procedural _draw (positions are data-driven and animated) but redraw it with layered outlined shapes in the wing painting's style; static parts may become SVG textures drawn with draw_texture. Grade badge: the grade SVGs become frame-and-marker overlays, and ForgeryCanvas._finish shows the traced painting's scan (with its style material) under the overlay, popped in together.

## Steps
1. Read character_rig.gd, mime.gd, guard.gd, ghost_mime.gd, rig_mime.tscn, rig_guard.tscn and the rig tests in full; design the two-part limb hierarchy and joint exports.
2. Implement jointed limbs in CharacterRig (_ready, _apply, _pose), keeping draw order, far-limb shading, mirroring and squash; update _test_rig_views and _test_rig_walk_cycle and add a test that knees bend while walking and straighten at rest.
3. Draw the new SVG limb parts and redrawn front, back and side bodies for the mime and guard; wire them into rig_mime.tscn and rig_guard.tscn (the ghost mime reuses the mime rig).
4. Redraw Puddles (wing 2) in woodblock-print style across the pipe, floor and spray layers; keep _test_puddles_checked_and_wired passing and pin any new animation rate in _test_no_flash_rates.
5. Redraw WindowLight, Footprints, Searchlights and the GimmickMix glass in their wings' styles, with the same rate pinning and Reduce Motion handling.
6. Turn grade_sloppy/good/perfect.svg into frame-and-marker overlays; add a picture node under Grade in the forgery canvas scene, set from the canvas's painting in _finish (unknown painting reported); update _test_canvas_traces_and_grades and add a per-wing badge-picture test.
7. Run tools/validate.sh and the full test suite, re-run the bot replays to prove routes are unchanged, and check every wing visually.
8. Update CLAUDE.md's architecture notes for the jointed rig, the restyled gimmicks and the grade badge.

## Deferred Ideas
(none — discussion stayed within task scope)

Last revised: 2026-11-03
