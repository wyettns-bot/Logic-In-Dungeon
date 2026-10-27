# Test bots

Bots that play the real game and check that its mechanics work. They test **rules, not
balance**: the test games give the player 250 HP, can make you unkillable, and add a key that
solves the current boss puzzle, so every fight reaches its end.

## Run them

```bash
python3 tools/tests/run_all.py          # everything (about 15-20 minutes)
python3 tools/tests/run_all.py 12 21    # just these boss floors
python3 tools/tests/boss_test.py 30     # one boss
python3 tools/tests/unbound_test.py     # the Unbound King's six forms
python3 tools/tests/warden_death_test.py
python3 tools/tests/demo_test.py        # the title's Demo button
```

Each test prints `PASS` or `FAIL` (with what was missing). `run_all.py` ends with a summary
and exits with an error code if anything failed.

**Needs:** `nasm`, `gcc` with raylib, and `xvfb-run`, which runs the game window invisibly
(Fedora: `sudo dnf install xorg-x11-server-Xvfb`, Ubuntu: `sudo apt install xvfb`). If raylib
is built from source, set `RAYLIB_DIR=/path/to/raylib/src` first.

Everything the tests make goes into `tools/tests/build/` (ignored by git): test builds of the
game, the test window, message logs and screenshots.

## What each test checks

| Test | Checks |
|---|---|
| `boss_test.py 4` / `8` | Warden: matching the gate breaks his shield, "Burn anew!" moves the torches, the door opens when he dies |
| `boss_test.py 12` | Four Bishops: hitting the 1 moves it, Smite and Judgment both land, all four fall together |
| `boss_test.py 15` | Dark Shade: the lantern blazes, the Shade shatters it, it dies |
| `boss_test.py 17` | Ymir: both power torches out leaves him spent, the blue wave relights them |
| `boss_test.py 21` | Logic Keeper: links get cut, both cut opens him, links come back with new gates |
| `boss_test.py 26` | Altair and Smo: when one falls the other absorbs its power |
| `boss_test.py 30` | Forgotten King: the blue cannon fires, both rewires happen, the fake death, he rises Unbound |
| `unbound_test.py` | The Unbound's forms come in order, at the right size, fully drawn, with the right number of copies |
| `warden_death_test.py` | The Keeper's Wardens attack, and a killed Warden vanishes and stays gone |
| `demo_test.py` | Demo mode: every room on the list comes up on the right floor with a levelled hero and goes back with Room list; the hero can't die; the door and the Unbound's death lead back to the list |

## The pieces

| File | What it is |
|---|---|
| `testbuild.py` | Builds a test copy of the game with cheats (`python3 tools/tests/testbuild.py NAME FLOOR hp250 god solve ...`). The real game is never changed; every patch checks the code it changes is still there |
| `test_solve.asm` | The `!` key used by the `solve` option: sets the torches so the current boss puzzle is beaten |
| `driver.py` | Starts the game window under Xvfb and scripts it: keys, clicks, screenshots, reading the game's text screen and its message log |
| `boss_test.py`, `unbound_test.py`, `warden_death_test.py`, `demo_test.py` | The tests |
| `run_all.py` | Runs them all |

The window only accepts these scripted commands when it is built with `-DRD_TEST`; the normal
`rd_gui` ignores them. For balance playtests, `tools/playbot.py` plays the real game in a
terminal emulator from floor 1.
