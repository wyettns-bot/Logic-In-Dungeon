#!/usr/bin/env python3
"""warden_death_test.py - the Logic Keeper's Wardens move, attack, and vanish when killed.

    python3 tools/tests/warden_death_test.py

Floor 21 with weak Wardens: the bot attacks the nearest Warden until one dies, then waits four
rounds. It passes if a Warden attacked, one died, and its body stayed gone.
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import driver as D
import testbuild


def run():
    game = testbuild.build("keeper_weak", 21, {"hp250", "god", "weakwardens"})
    D.start(game, "keeper.log")
    D.new_game("1")
    mcells = lambda s: [(x, y) for x, y, c in D.find(s, "M")]
    n0 = len(mcells(D.screen(0.2))); died = False
    for step in range(150):
        s = D.screen(0.15); m = mcells(s)
        if len(m) < n0: died = True; break
        me = D.find(s, "@")
        if me and m:
            p = me[0][:2]; c = min(m, key=lambda q: D.cheb(p, q))
            D.click(*c); time.sleep(0.45); D.click(*c); time.sleep(0.45)
        D.cmd("key  "); time.sleep(1.4)
    left = len(mcells(D.screen(0.2)))
    for k in range(4):
        D.cmd("key  "); time.sleep(1.6)
    after = len(mcells(D.screen(0.3)))
    D.shot("keeper_after.png")
    D.stop()
    attacks = sum(1 for l in D.messages() if "Warden hits you" in l or "Warden misses" in l)
    ok = died and after == left and attacks > 0
    print(f"{'PASS' if ok else 'FAIL'}  Keeper's Wardens: attacks {attacks}, a Warden died: {died}, "
          f"Warden cells {n0} -> {left} -> {after} after 4 rounds")
    return ok


if __name__ == "__main__":
    sys.exit(0 if run() else 1)
