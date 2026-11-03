#!/usr/bin/env python3
"""Writes the six floor tile SVGs (one per wing), floor_<pattern>.svg, into afterhours/art/svg
(or the folder given as the first argument). Run from the repository root: python3 tools/floors.py

Every tile is drawn already flattened to the room's 3/4 view (floor depth halved) and
wraps seamlessly: anything crossing an edge is drawn again on the opposite side.
"""
import random
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "afterhours/art/svg"


def svg(name, w, h, body):
    with open(f"{OUT}/floor_{name}.svg", "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n{body}</svg>\n')


def wrapped(w, h, draw):
    """`draw(dx, dy)` repeated at the eight neighbouring offsets too, for seamless wrap."""
    return "".join(draw(dx * w, dy * h) for dx in (-1, 0, 1) for dy in (-1, 0, 1))


# 1 Vermeer: black and white marble laid on the diagonal, thin grey grout, faint veins.
checker = """  <rect width="64" height="32" fill="#e6e1d6"/>
  <polygon points="32,0 64,16 32,32 0,16" fill="#2b2a31" stroke="#8d877c" stroke-width="0.7"/>
  <path d="M6 3 Q12 6 10 11 M52 25 Q58 27 57 31 M50 2 Q55 5 60 4" stroke="#c9c2b4" stroke-width="0.5" fill="none"/>
  <path d="M24 13 Q30 16 38 15 M30 21 Q34 19 40 22" stroke="#45434d" stroke-width="0.5" fill="none"/>
"""
svg("checker", 64, 32, checker)

# 2 Hokusai: tatami laid in pairs that turn by turns (two mats lying across, then two
# standing), so no seam runs on; a dark cloth border (heri) along each mat's long edges, the
# rush weave running the mat's length, a fine seam across its short ends.
HERI = "#34402f"


def mat_across(x, y):
    weave = "".join(f'<line x1="{x + k:.1f}" y1="{y + 1.2}" x2="{x + k:.1f}" y2="{y + 14.8}" stroke="#a89f62" stroke-width="0.35"/>' for k in [i * 2.5 + 1.2 for i in range(26)])
    return (f'<rect x="{x}" y="{y}" width="64" height="16" fill="url(#straw)"/>{weave}'
            f'<rect x="{x}" y="{y}" width="64" height="1.2" fill="{HERI}"/><rect x="{x}" y="{y + 14.8}" width="64" height="1.2" fill="{HERI}"/>'
            f'<path d="M{x + 0.3} {y} V{y + 16} M{x + 63.7} {y} V{y + 16}" stroke="#7d7442" stroke-width="0.6"/>')


def mat_standing(x, y):
    weave = "".join(f'<line x1="{x + 2.4}" y1="{y + k:.1f}" x2="{x + 29.6}" y2="{y + k:.1f}" stroke="#a89f62" stroke-width="0.3"/>' for k in [i * 1.6 + 0.8 for i in range(20)])
    return (f'<rect x="{x}" y="{y}" width="32" height="32" fill="url(#straw)"/>{weave}'
            f'<rect x="{x}" y="{y}" width="2.4" height="32" fill="{HERI}"/><rect x="{x + 29.6}" y="{y}" width="2.4" height="32" fill="{HERI}"/>'
            f'<path d="M{x} {y + 0.3} H{x + 32} M{x} {y + 31.7} H{x + 32}" stroke="#7d7442" stroke-width="0.5"/>')


mats = (mat_across(0, 0) + mat_across(0, 16) + mat_standing(64, 0) + mat_standing(96, 0)
        + mat_standing(0, 32) + mat_standing(32, 32) + mat_across(64, 32) + mat_across(64, 48))
svg("tatami", 128, 64, """  <defs><linearGradient id="straw" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#d1c88a"/><stop offset="1" stop-color="#bdb26e"/></linearGradient></defs>
  """ + mats + "\n")

# 3 Seurat: terrazzo in brass-stripped panels, its chips dabs of the Grande Jatte's palette.
rnd = random.Random(1884)
chips = []
palette = ["#e08a3c", "#3d6fb0", "#5f9a4a", "#8a5aa8", "#d9b44a", "#c8574a", "#2f3a4a", "#f2efe6"]
for _ in range(70):
    x, y = rnd.uniform(0, 96), rnd.uniform(0, 48)
    rx = rnd.uniform(0.6, 1.8)
    colour = rnd.choice(palette)
    chips.append(wrapped(96, 48, lambda dx, dy, x=x, y=y, rx=rx, c=colour: f'<ellipse cx="{x + dx:.1f}" cy="{y + dy:.1f}" rx="{rx:.1f}" ry="{rx * 0.55:.1f}" fill="{c}"/>'))
svg("terrazzo", 96, 48, '  <rect width="96" height="48" fill="#d6cebd"/>\n  ' + "".join(chips)
    + '\n  <path d="M0 0.4 H96 M0.4 0 V48" stroke="#b08a3c" stroke-width="0.8"/>\n')

# 4 Van Gogh: the Café Terrace's cobbles, rounded stones in staggered rows, slate blue and
# violet under the night, each lit along its top.
rnd = random.Random(1888)
stones = []
tones = ["#5d6c90", "#53608a", "#6a7598", "#5a5f86", "#4c5878"]
for row in range(2):
    for k in range(5):
        x = k * 20 + (10 if row else 0)
        y = row * 10
        colour = rnd.choice(tones)
        stones.append(wrapped(80, 20, lambda dx, dy, x=x, y=y, c=colour:
            f'<rect x="{x + 1 + dx}" y="{y + 1 + dy}" width="18" height="8" rx="4" ry="3" fill="{c}"/>'
            f'<path d="M{x + 4 + dx} {y + 2.6 + dy} H{x + 16 + dx}" stroke="#8792b4" stroke-width="0.9" stroke-linecap="round"/>'))
svg("cobble", 80, 20, '  <rect width="80" height="20" fill="#272c3f"/>\n  ' + "".join(stones) + "\n")

# 5 Bosch: glazed medieval tiles, a cream octagon in each square with small diamond tiles
# at the corners, a ring and a tiny quatrefoil in each; drawn light so each room's colour
# (Eden, the Garden, Hell) tints it.
octagon = " ".join(f"{x},{y / 2}" for x, y in [(14, 0), (34, 0), (48, 14), (48, 34), (34, 48), (14, 48), (0, 34), (0, 14)])
inner = " ".join(f"{x},{y / 2}" for x, y in [(17, 4), (31, 4), (44, 17), (44, 31), (31, 44), (17, 44), (4, 31), (4, 17)])
svg("gothic", 48, 24, f"""  <rect width="48" height="24" fill="#8e6a4c"/>
  <polygon points="{octagon}" fill="#efe7d4" stroke="#5e4634" stroke-width="0.7"/>
  <polygon points="{inner}" fill="none" stroke="#b9a483" stroke-width="0.6"/>
  <g fill="#a3876a"><circle cx="24" cy="10" r="2"/><circle cx="24" cy="14" r="2"/><circle cx="20" cy="12" r="2"/><circle cx="28" cy="12" r="2"/></g>
  <circle cx="24" cy="12" r="1.2" fill="#efe7d4"/>
""")

# 6 Mona Lisa: the Louvre's oak parquet in basket weave, three planks a square, the squares
# turning by turns; each plank its own shade.
rnd = random.Random(1503)
woods = ["#8b5b33", "#9a6739", "#7e522e", "#93623a", "#865732"]
planks = []
for bx, by, across in [(0, 0, True), (24, 0, False), (0, 12, False), (24, 12, True)]:
    for k in range(3):
        colour = rnd.choice(woods)
        if across:
            planks.append(f'<rect x="{bx}" y="{by + k * 4}" width="24" height="4" fill="{colour}" stroke="#4a2e1a" stroke-width="0.5"/>')
            planks.append(f'<path d="M{bx + 2} {by + k * 4 + 2} H{bx + 22}" stroke="#a87545" stroke-width="0.3" opacity="0.7"/>')
        else:
            planks.append(f'<rect x="{bx + k * 8}" y="{by}" width="8" height="12" fill="{colour}" stroke="#4a2e1a" stroke-width="0.5"/>')
            planks.append(f'<path d="M{bx + k * 8 + 4} {by + 1} V{by + 11}" stroke="#a87545" stroke-width="0.3" opacity="0.7"/>')
svg("parquet", 48, 24, "  " + "".join(planks) + "\n")
