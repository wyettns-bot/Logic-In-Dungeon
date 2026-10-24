"""Lays out the circuit templates on the 51x13 room grid, checks them, prints an ASCII preview,
and writes circuits.inc (the data tables the assembly reads)."""
import os as _os
_os.chdir(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))   # run from anywhere: work in the game folder
import sys

W, H = 51, 13
DOOR = [(50, 5), (50, 6), (50, 7)]
PLAQUE = (50, 9)

def path(*pts):
    cells = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        assert x0 == x1 or y0 == y1, "segments must be straight"
        dx = (x1 > x0) - (x1 < x0); dy = (y1 > y0) - (y1 < y0)
        x, y = x0, y0
        while True:
            if (x, y) not in cells: cells.append((x, y))
            if (x, y) == (x1, y1): break
            x += dx; y += dy
    return cells

# a template: torches (left cell x, y), gates (inputA, inputB or None for NOT, centre x, centre y),
# wires [(node, cells)], output node.  Nodes 0..3 = torches, 4.. = gates in order.
def T_A():          # (A ? B) ? C
    torches = [(24, 1), (24, 5), (24, 10)]
    gates = [(0, 1, 33, 3), (4, 2, 42, 6)]
    wires = [(0, path((27, 1), (31, 1), (31, 2))),
             (1, path((27, 5), (31, 5), (31, 4))),
             (4, path((35, 3), (40, 3), (40, 5))),
             (2, path((27, 10), (40, 10), (40, 7))),
             (5, path((44, 6), (49, 6)))]
    return torches, gates, wires, 5

def T_C():          # (A ? B) ? NOT C
    torches = [(24, 1), (24, 5), (24, 10)]
    gates = [(0, 1, 33, 3), (2, None, 33, 10), (4, 5, 42, 6)]
    wires = [(0, path((27, 1), (31, 1), (31, 2))),
             (1, path((27, 5), (31, 5), (31, 4))),
             (2, path((27, 10), (31, 10))),
             (4, path((35, 3), (40, 3), (40, 5))),
             (5, path((35, 10), (40, 10), (40, 7))),
             (6, path((44, 6), (49, 6)))]
    return torches, gates, wires, 6

def T_B():          # (A ? B) ? (C ? D)
    torches = [(24, 0), (24, 4), (24, 8), (24, 12)]
    gates = [(0, 1, 33, 2), (2, 3, 33, 10), (4, 5, 42, 6)]
    wires = [(0, path((27, 0), (31, 0), (31, 1))),
             (1, path((27, 4), (31, 4), (31, 3))),
             (2, path((27, 8), (31, 8), (31, 9))),
             (3, path((27, 12), (31, 12), (31, 11))),
             (4, path((35, 2), (40, 2), (40, 5))),
             (5, path((35, 10), (40, 10), (40, 7))),
             (6, path((44, 6), (49, 6)))]
    return torches, gates, wires, 6

# ---- boss rooms. Their gates may face other ways (the GUI rotates them), so they skip
#      the left-to-right checks but still must not overlap or touch wrongly.
def T_S():          # the Dark Shade: (A ? B) and (C ? D) both light the lantern (node 6, a fixed AND)
    torches = [(8, 2), (8, 10), (40, 2), (40, 10)]
    gates = [(0, 1, 16, 6), (3, 2, 34, 6), (4, 5, 25, 6)]          # the right gate faces left
    wires = [(0, path((11, 2), (14, 2), (14, 5))),
             (1, path((11, 10), (14, 10), (14, 7))),
             (2, path((39, 2), (36, 2), (36, 5))),
             (3, path((39, 10), (36, 10), (36, 7))),
             (4, path((18, 6), (23, 6))),
             (5, path((32, 6), (27, 6)))]
    return torches, gates, wires, 6

def T_Y():          # Grand Wizard Ymir: top pair -> top gate (inputs from above), bottom pair -> bottom gate
    torches = [(8, 1), (40, 1), (8, 11), (40, 11)]                  # TL TR BL BR
    gates = [(1, 0, 25, 3), (2, 3, 25, 9)]
    wires = [(0, path((11, 1), (24, 1))),
             (1, path((39, 1), (26, 1))),
             (2, path((11, 11), (24, 11))),
             (3, path((39, 11), (26, 11)))]
    return torches, gates, wires, 4

def T_K():          # the Forgotten King's throne: (A ? B) ? (C ? D), the last wire runs to the blue cannon torch (34,6)
    torches = [(8, 0), (8, 4), (8, 8), (8, 12)]
    gates = [(0, 1, 17, 2), (2, 3, 17, 10), (4, 5, 26, 6)]
    wires = [(0, path((11, 0), (15, 0), (15, 1))),
             (1, path((11, 4), (15, 4), (15, 3))),
             (2, path((11, 8), (15, 8), (15, 9))),
             (3, path((11, 12), (15, 12), (15, 11))),
             (4, path((19, 2), (24, 2), (24, 5))),
             (5, path((19, 10), (24, 10), (24, 7))),
             (6, path((28, 6), (33, 6)))]
    return torches, gates, wires, 6

TEMPLATES = [("A", T_A()), ("C", T_C()), ("B", T_B()), ("S", T_S()), ("Y", T_Y()), ("K", T_K())]
BOSS = {"S", "Y", "K"}

def check_boss(name, t):
    torches, gates, wires, out = t
    grid = [["." for _ in range(W)] for _ in range(H)]
    owner = {}
    def put(x, y, ch, what):
        assert 0 <= x < W and 0 <= y < H, (name, what, x, y)
        assert (x, y) not in owner, (name, "overlap", what, owner[(x, y)], (x, y))
        owner[(x, y)] = what; grid[y][x] = ch
    for i, (x, y) in enumerate(torches):
        for k, ch in enumerate("[0]"): put(x + k, y, ch, ("torch", i))
    for g, (a, b, cx, cy) in enumerate(gates):
        for yy in range(cy - 1, cy + 2):
            for xx in range(cx - 1, cx + 2): put(xx, yy, "G" if (xx, yy) == (cx, cy) else "%", ("gate", 4 + g))
    for node, cells in wires:
        for (x, y) in cells: put(x, y, "-", ("wire", node))
    for (x, y) in DOOR: put(x, y, ">", ("door",))
    for node, cells in wires:                       # different signals never touch
        for (x, y) in cells:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                o = owner.get((nx, ny))
                if o and o[0] == "wire": assert o[1] == node, (name, "wires touch", (x, y), (nx, ny))
    print("boss template", name, "OK")
    for row in grid: print("   " + "".join(row))

def check_and_draw(name, t):
    if name in BOSS: return check_boss(name, t)
    torches, gates, wires, out = t
    grid = [["." for _ in range(W)] for _ in range(H)]
    owner = {}
    def put(x, y, ch, what):
        assert 0 <= x < W and 0 <= y < H, (name, what, x, y)
        assert (x, y) not in owner, (name, "overlap", what, owner[(x, y)], (x, y))
        owner[(x, y)] = what; grid[y][x] = ch
    for i, (x, y) in enumerate(torches):
        for k, ch in enumerate("[0]"): put(x + k, y, ch, ("torch", i))
    for g, (a, b, cx, cy) in enumerate(gates):
        for yy in range(cy - 1, cy + 2):
            for xx in range(cx - 1, cx + 2):
                put(xx, yy, "N" if b is None and (xx, yy) == (cx, cy) else ("G" if (xx, yy) == (cx, cy) else "%"), ("gate", 4 + g))
    for node, cells in wires:
        for (x, y) in cells: put(x, y, "-", ("wire", node))
    for (x, y) in DOOR: put(x, y, ">", ("door",))
    put(*PLAQUE, "R", ("plaque",))
    # wires of different signals must never touch; a wire may only touch its own source and its sink
    def at(x, y): return owner.get((x, y))
    for node, cells in wires:
        for (x, y) in cells:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                o = at(nx, ny)
                if o and o[0] == "wire": assert o[1] == node, (name, "wires touch", (x, y), (nx, ny))
        # endpoints: first cell touches its source, last cell touches its sink
        src = ("torch", node) if node < 4 else ("gate", node)
        first, last = cells[0], cells[-1]
        assert any(at(nx, ny) == src for nx, ny in ((first[0] - 1, first[1]),)), (name, "wire start", node)
        sinks = [4 + g for g, (a, b, cx, cy) in enumerate(gates) if node in (a, b)]
        if node == out:
            assert at(last[0] + 1, last[1]) == ("door",), (name, "output wire must reach the door")
        else:
            assert len(sinks) == 1 and at(last[0] + 1, last[1]) == ("gate", sinks[0]), (name, "wire end", node)
        # gate inputs enter at the right rows: A at the top row, B at the bottom row, NOT in the middle
        if node != out:
            a, b, cx, cy = gates[sinks[0] - 4]
            want_y = cy if b is None else (cy - 1 if node == a else cy + 1)
            assert last[1] == want_y, (name, "wire enters the wrong row", node)
        # no stray contact with other gates' borders
        for (x, y) in cells:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                o = at(nx, ny)
                if o and o[0] == "gate" and o != src and not ((x, y) == last and node != out and o == ("gate", sinks[0])):
                    raise AssertionError((name, "wire grazes a gate", node, (x, y), o))
    print("template", name, "OK")
    for row in grid: print("   " + "".join(row))

for name, t in TEMPLATES: check_and_draw(name, t)

# ---- circuits.inc ----
o = []
o.append("; circuits.inc - generated by gen_circuits.py (the room layouts of the circuit puzzles)")
o.append("; per template:  torches: count, then x,y   gates: count, then inA, inB (255 = NOT gate), cx, cy")
o.append(";                wires: count (word), then x, y, node   and the output node")
o.append("CIRC_TEMPLATES equ %d" % len(TEMPLATES))
names = []
for name, (torches, gates, wires, out) in TEMPLATES:
    lab = "circ_" + name
    names.append(lab)
    o.append("%s_torches db %d, %s" % (lab, len(torches), ", ".join("%d,%d" % p for p in torches)))
    o.append("%s_gates db %d, %s" % (lab, len(gates), ", ".join("%d,%d,%d,%d" % (a, 255 if b is None else b, cx, cy) for a, b, cx, cy in gates)))
    cells = [(x, y, node) for node, cs in wires for (x, y) in cs]
    o.append("%s_wires dw %d" % (lab, len(cells)))
    for i in range(0, len(cells), 12):
        o.append("    db " + ", ".join("%d,%d,%d" % c for c in cells[i:i + 12]))
    o.append("%s_out db %d" % (lab, out))
o.append("circTorchTab dd " + ", ".join(n + "_torches" for n in names))
o.append("circGateTab dd " + ", ".join(n + "_gates" for n in names))
o.append("circWireTab dd " + ", ".join(n + "_wires" for n in names))
o.append("circOutTab dd " + ", ".join(n + "_out" for n in names))
o.append("CT_A equ 0")
o.append("CT_C equ 1")
o.append("CT_B equ 2")
o.append("CT_S equ 3")
o.append("CT_Y equ 4")
o.append("CT_K equ 5")
open("circuits.inc", "w").write("\n".join(o) + "\n")
print("wrote circuits.inc")
