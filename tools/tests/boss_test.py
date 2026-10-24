#!/usr/bin/env python3
"""boss_test.py - play one boss fight with a bot and check that its mechanics happen.

    python3 tools/tests/boss_test.py FLOOR          (4, 8, 12, 15, 17, 21, 26 or 30)

The test game starts on that floor as a fighter with 250 HP who can't die, and the '!' key
solves the boss's torch puzzle (the bot presses it each turn) - so the test checks the boss's
RULES, not the balance. The bot attacks the right body (it reads the bishops' gates to find
the 1). It passes when every expected message for that boss shows up and the fight ends.
"""
import itertools, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import driver as D
from testbuild import build

EXPECT = {     # floor -> (name, messages that must appear, how the fight must end)
    4:  ("Warden", ["The gate opens - the Warden's shield breaks", "WARDEN: Burn anew!"], "door grinds open"),
    8:  ("Warden", ["The gate opens - the Warden's shield breaks", "WARDEN: Burn anew!"], "door grinds open"),
    12: ("Four Bishops", ["Found the 1!", "The bishops cast Smite", "The bishops cast Judgment"], "door grinds open"),
    15: ("Dark Shade", ["The lantern blazes!", "The Shade shatters the lantern"], "door grinds open"),
    17: ("Grand Wizard Ymir", ["Ymir's power is spent!", "Ymir's blue wave"], "door grinds open"),
    21: ("Logic Keeper", ["A Warden's link is cut!", "Both links are cut", "A Warden links to the Keeper again"], "door grinds open"),
    26: ("Altair and Smo", ["absorbs"], "door grinds open"),
    30: ("Forgotten King", ["The blue torch fires!", "The circuit rewires itself", "Every gate goes dark",
                           "The Forgotten King has fallen", "UNBOUND!"], "The Unbound shakes the room"),
}
TARGET = {4: "M", 8: "M", 15: "Dd", 17: "Y", 21: "Jj", 30: "K"}


def bishop_target(s):
    """Read the four gates on the square and return the cells of a bishop that is a 1."""
    G = {"v": 0, "X": 1, "A": 2}
    gl = [s[y + 6][x + 1] for x, y in [(25, 2), (42, 6), (25, 11), (9, 6)]]
    for bits in itertools.product((0, 1), repeat=4):
        if all(G.get(gl[k], -1) == bits[k] + bits[(k + 1) % 4] for k in range(4)):
            cx, cy = [(8, 1), (41, 1), (41, 10), (8, 10)][bits.index(1)]
            return [(cx, cy), (cx + 1, cy), (cx, cy + 1), (cx + 1, cy + 1)]
    return None


def run(floor, max_steps=260):
    name, need, end = EXPECT[floor]
    game = build(f"boss{floor}", floor, {"hp250", "god", "solve"})
    D.start(game, f"boss{floor}.log")
    D.new_game("1")
    done = False
    for step in range(max_steps):
        s = D.screen(0.15)
        msgs = "\n".join(D.messages())
        if end in msgs:
            done = True; break
        if floor != 12 and floor != 26:
            D.cmd("key !"); time.sleep(0.25)          # solve the boss puzzle
        if floor == 12: t = bishop_target(s)
        elif floor == 26: t = [(x, y) for x, y, c in D.find(s, "TtF")] or [(x, y) for x, y, c in D.find(s, "UuH")]
        else: t = [(x, y) for x, y, c in D.find(s, TARGET[floor])]
        me = D.find(s, "@")
        if t and me:
            p = me[0][:2]; c = min(t, key=lambda q: D.cheb(p, q))
            D.click(*c); time.sleep(0.45); D.click(*c); time.sleep(0.45)   # walk there, then attack
        D.cmd("key  "); time.sleep(1.3)                 # end the turn
    D.shot(f"boss{floor}_end.png")
    D.stop()
    msgs = "\n".join(D.messages())
    missing = [m for m in need if m not in msgs]
    ok = done and not missing
    print(f"{'PASS' if ok else 'FAIL'}  floor {floor:2} {name:18}" +
          ("" if ok else f"  missing: {missing}{'' if done else ' / the fight never ended'}"))
    return ok


if __name__ == "__main__":
    if len(sys.argv) < 2 or int(sys.argv[1]) not in EXPECT:
        sys.exit(__doc__)
    sys.exit(0 if run(int(sys.argv[1])) else 1)
