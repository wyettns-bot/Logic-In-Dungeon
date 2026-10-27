#!/usr/bin/env python3
"""demo_test.py - check the window's demo mode.

    python3 tools/tests/demo_test.py

1. Rooms: picks every entry of the demo list (by clicking its button), checks that the right
   floor comes up with its boss or puzzle and a levelled hero, screenshots it, and comes back
   with the Room list button.
2. Endings (a test build where every demo room starts the hero at 1 HP and the Unbound has 1 HP):
   in the Bishops' room their spells bring the hero to 0 and it is saved instead of dying; the
   Warden falls and his door leads back to the list; killing the Unbound leads back there too.
"""
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import driver as D
from testbuild import build

#  letter, floor, what must be in the messages (or "map:" + a map letter: N = a NOT gate, ? = a hidden gate), the hero's level
ROOMS = [
    ("a", 2, None, 1), ("b", 5, None, 3), ("c", 16, None, 11), ("d", 22, "map:N", 15), ("e", 25, "map:?", 16),
    ("f", 4, "Warden", 3), ("g", 12, "Bishops", 8), ("h", 15, "Shade", 10), ("i", 17, "Ymir", 12),
    ("j", 21, "Keeper", 14), ("k", 26, "Altair", 17), ("l", 30, "King", 18), ("m", 30, "UNBOUND!", 18),
]
ROOM_LIST = "uiclick 1629 600"


def button(letter):   # the demo screen's button for that room (window coordinates)
    i = ord(letter) - ord("a")
    if i < 5: return 430, 282 + 86 * i
    i -= 5
    return 956 + 392 * (i // 4), 292 + 108 * (i % 4)


def start_demo(game, log):
    D.start(game, log)
    time.sleep(0.8)
    D.cmd("uiclick 630 749"); time.sleep(1.0)        # the title's Demo button
    D.cmd("key 1\\n"); time.sleep(0.6); D.cmd("key y\\n"); time.sleep(0.5)
    for k in "444": D.cmd("key " + k + "\\n"); time.sleep(0.3)
    time.sleep(2)


def on_list(s): return any("DEMO MODE: choose a room" in r for r in s)


def pick(letter):
    x, y = button(letter); D.cmd(f"uiclick {x} {y}"); time.sleep(2.5)


def status(s):
    t = "\n".join(s[:4])
    f = re.search(r"Floor: (\d+)", t); lv = re.search(r"Lv:(\d+)", t); hp = re.search(r"HP: (\d+)/(\d+)", t)
    return (int(f.group(1)) if f else 0, int(lv.group(1)) if lv else 0, (int(hp.group(1)), int(hp.group(2))) if hp else (0, 0))


def rooms():
    game = build("demo", 1, set())
    start_demo(game, "demo.log")
    fails = []
    s = D.screen()
    if not on_list(s): fails.append("the room list never showed up")
    for letter, floor, want, minlv in ROOMS:
        before = len(D.messages())
        pick(letter)
        s = D.screen(0.6)
        f, lv, hp = status(s)
        text = "\n".join(s) + "\n".join(D.messages()[before:])
        problems = []
        if f != floor: problems.append(f"floor {f}")
        if lv != minlv: problems.append(f"level {lv}")
        if hp[0] != hp[1]: problems.append(f"HP {hp[0]}/{hp[1]}")
        if want and want.startswith("map:"):
            if not D.find(s, want[4:]): problems.append(f"no '{want[4:]}' on the map")
        elif want and want not in text: problems.append(f"no '{want}'")
        D.shot(f"demo_{letter}.png")
        D.cmd(ROOM_LIST); time.sleep(1.5)
        if not on_list(D.screen()): problems.append("Room list didn't go back")
        print(f"{'ok  ' if not problems else 'BAD '} {letter}  floor {floor:2}  level {lv:2}  {', '.join(problems)}")
        if problems: fails.append(f"{letter}: {', '.join(problems)}")
    D.stop()
    return fails


def fight(target, until, steps=80):
    """Walk to and hit `target` map letters, ending turns, until a message containing `until` shows."""
    saved = False
    for _ in range(steps):
        s = D.screen(0.15)
        msgs = "\n".join(D.messages())
        saved = saved or "you can't die here" in msgs
        if until in msgs or on_list(s): return True, saved, s
        D.cmd("key !"); time.sleep(0.25)
        t = [(x, y) for x, y, c in D.find(s, target)]
        me = D.find(s, "@")
        if t and me:
            p = me[0][:2]; c = min(t, key=lambda q: D.cheb(p, q))
            D.click(*c); time.sleep(0.45); D.click(*c); time.sleep(0.45)
        D.cmd("key  "); time.sleep(1.3)
    return False, saved, D.screen()


def endings():
    game = build("demo_end", 1, {"frail", "solve", "frailunbound"})
    start_demo(game, "demo_end.log")
    fails = []
    pick("g")                                          # the Bishops' spells always land: the hero on 1 HP is saved
    for _ in range(30):
        if "you can't die here" in "\n".join(D.messages()): break
        D.cmd("key  "); time.sleep(1.3)
    if "you can't die here" not in "\n".join(D.messages()): fails.append("never saw 'you can't die here'")
    D.cmd(ROOM_LIST); time.sleep(1.5)
    pick("f")                                          # the Warden: beat him, then out through the door
    ok, saved, s = fight("M", "door grinds open", 120)
    if not ok: fails.append("the Warden never fell")
    for _ in range(12):                                # walk out through the door
        s = D.screen(0.2)
        if on_list(s): break
        door = D.find(s, ">")
        if door: D.click(*door[len(door) // 2][:2])
        time.sleep(1.2)
    if not on_list(D.screen()): fails.append("the door didn't lead back to the list")
    D.shot("demo_door_back.png")
    pick("m")                                          # the Unbound, on 1 HP
    ok, _, s = fight("Z", "DEMO MODE", 40)
    if not on_list(D.screen()): fails.append("killing the Unbound didn't lead back to the list")
    D.stop()
    if "You died" in "\n".join(D.messages()): fails.append("the hero died in demo mode")
    print(f"{'ok  ' if not fails else 'BAD '} endings  {', '.join(fails)}")
    return fails


if __name__ == "__main__":
    fails = rooms() + endings()
    print("PASS  demo mode" if not fails else "FAIL  demo mode: " + "; ".join(fails))
    sys.exit(1 if fails else 0)
