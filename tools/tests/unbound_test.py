#!/usr/bin/env python3
"""unbound_test.py - the Unbound King's forms: right order, right size, copies where they belong.

    python3 tools/tests/unbound_test.py

A test game where the King rises as the Unbound at once and changes form after every boss turn.
The bot just ends turns and checks each form as it appears: his body's size, that every cell of
it is drawn, and how many copies of him ('z') stand in the room. Screenshots of every form are
saved in tools/tests/build/.
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import driver as D
from testbuild import build

ORDER = ["WARDEN", "BISHOPS", "SHADE", "YMIR", "KEEPER", "ALTAIR & SMO"]
SIZES = {"WARDEN": [(3, 3)], "BISHOPS": [(2, 2)], "SHADE": [(5, 3)], "YMIR": [(4, 4)], "KEEPER": [(4, 4)],
         "ALTAIR & SMO": [(2, 2), (4, 4)]}
COPIES = {"BISHOPS": 3, "ALTAIR & SMO": 1}       # extra bodies of him in that form (the rest: none)


def body(s):
    Z = [(c, r) for r in range(6, 19) for c in range(1, 52) if s[r][c] == "Z"]
    if not Z: return None
    c0 = min(c for c, r in Z); r0 = min(r for c, r in Z)
    w = max(c for c, r in Z) - c0 + 1; h = max(r for c, r in Z) - r0 + 1
    return c0, r0, w, h, s[r0 + h // 2][c0 + w // 2]


def form(ch):
    return ("WARDEN" if ch in "AVXavEN" else "BISHOPS" if ch == "q" else "SHADE" if ch in "Dd" else
            "YMIR" if ch == "f" else "KEEPER" if ch in "Ww" else "ALTAIR & SMO" if ch in "01" else "?" + ch)


def run():
    game = build("unbound_cycle", 30, {"hp250", "unbound", "cycle"})
    D.start(game, "unbound.log")
    D.new_game("1")
    seen, ok = [], True
    for step in range(60):
        s = D.screen(0.3)
        b = body(s)
        if b:
            c0, r0, w, h, ch = b
            f = form(ch)
            if not seen or seen[-1] != f:
                seen.append(f)
                cells = sum(1 for y in range(h) for x in range(w) if s[r0 + y][c0 + x] in "Z" + ch)
                zc = sum(row[1:52].count("z") for row in s[6:19])
                # each copy is drawn as 'z' cells plus one middle letter: bishop copies are 2x2, and in
                # Altair & Smo the copy is the other size (2x2 beside a 4x4 Unbound, or 4x4 beside a 2x2)
                cw, chh = (4, 4) if (f == "ALTAIR & SMO" and (w, h) == (2, 2)) else (2, 2)
                copies = zc // (cw * chh - 1)
                good = (w, h) in SIZES.get(f, []) and cells == w * h and copies == COPIES.get(f, 0)
                ok &= good
                print(f"{'ok ' if good else 'BAD'} {f:13} {w}x{h}  body cells {cells}/{w*h}  copies {copies}")
                D.shot(f"unbound_{len(seen)}_{f.replace(' & ', '_').lower()}.png", 0.5)
        if len(seen) >= len(ORDER) + 2: break
        D.cmd("key  "); time.sleep(1.2)
    D.stop()
    want = (ORDER * 2)[:len(seen)]
    ok &= seen == want and len(seen) >= len(ORDER) + 1
    print(f"{'PASS' if ok else 'FAIL'}  Unbound forms: " + " -> ".join(seen))
    return ok


if __name__ == "__main__":
    sys.exit(0 if run() else 1)
