"""driver.py - run the game window invisibly (Xvfb) and script it, for the test bots.

The window is built with -DRD_TEST into tools/tests/build/rd_gui_test. In that mode it reads
commands from a script file, and logs every game message to a file:

    key <text>          type keys (\\n = Enter)
    uiclick <x> <y>     click at window coordinates
    shot <name>         screenshot (moved into tools/tests/build/)
    dump <path>         write the game's 80x26 text screen to a file
    quit
"""
import os, subprocess, time, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BUILD = os.path.join(HERE, "build")
SCRIPT = os.path.join(BUILD, "live.txt")
DUMP = os.path.join(BUILD, "live_dump.txt")
GUI = os.path.join(BUILD, "rd_gui_test")
proc = None
msglog = None


def build_gui(force=False):
    """Build the test window once (uses $RAYLIB_DIR if raylib is built from source)."""
    os.makedirs(BUILD, exist_ok=True)
    if os.path.exists(GUI) and not force and os.path.getmtime(GUI) > os.path.getmtime(os.path.join(ROOT, "rd_gui.c")):
        return
    rl = os.environ.get("RAYLIB_DIR")
    cmd = ["gcc", "-O2", "-DRD_TEST", os.path.join(ROOT, "rd_gui.c"), "-o", GUI]
    cmd += (["-I" + rl, "-L" + rl, "-lraylib", "-lGL", "-lm", "-lpthread", "-ldl", "-lrt", "-lX11", "-lutil"] if rl
            else ["-lraylib", "-lm", "-lutil"])
    subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)


def start(game, log_name="messages.log"):
    """Start the window running the test game binary `game`. Every game message goes to build/<log_name>."""
    global proc, msglog
    if not shutil.which("xvfb-run"):
        raise SystemExit("driver: needs xvfb-run (Fedora: sudo dnf install xorg-x11-server-Xvfb; Ubuntu: sudo apt install xvfb)")
    build_gui()
    open(SCRIPT, "w").close()
    msglog = os.path.join(BUILD, log_name)
    if os.path.exists(msglog): os.remove(msglog)
    env = dict(os.environ, RD_SCRIPT=SCRIPT, RD_MSGLOG=msglog, RD_SNDLOG=os.path.join(BUILD, "sounds.log"))
    proc = subprocess.Popen(["xvfb-run", "-a", "-s", "-screen 0 1800x950x24", GUI, game], cwd=ROOT, env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.6)


def cmd(*lines):
    with open(SCRIPT, "a") as f:
        for l in lines: f.write(l + "\n")


def screen(wait=0.4):
    """The game's text screen as a list of rows (the map is rows 6-18, columns 1-51)."""
    time.sleep(wait)
    if os.path.exists(DUMP): os.remove(DUMP)
    cmd("dump " + DUMP)
    for _ in range(80):
        time.sleep(0.05)
        if os.path.exists(DUMP) and os.path.getsize(DUMP) >= 26 * 80: break
    return open(DUMP).read().split("\n")


def shot(name, wait=0.35):
    """Screenshot of the window -> build/<name>. (raylib saves it in the window's working folder,
    the project root, so it is moved into build/ once written.)"""
    time.sleep(wait)
    raw, p = os.path.join(ROOT, name), os.path.join(BUILD, name)
    for f in (raw, p):
        if os.path.exists(f): os.remove(f)
    cmd("shot " + name)
    for _ in range(80):
        time.sleep(0.05)
        if os.path.exists(raw) and os.path.getsize(raw) > 1000: break
    time.sleep(0.3)
    if os.path.exists(raw): shutil.move(raw, p)
    return p


def messages():
    return open(msglog).read().split("\n") if msglog and os.path.exists(msglog) else []


def stop():
    cmd("quit"); time.sleep(0.8)
    try: proc.wait(timeout=5)
    except Exception: proc.kill()


def new_game(cls="1"):
    """From the title screen: Start, pick a class (1 Fighter, 2 Rogue, 3 Wizard), accept the stats."""
    cmd("uiclick 485 749"); time.sleep(1.0)
    cmd(f"key {cls}\\n"); time.sleep(0.6); cmd("key y\\n"); time.sleep(0.5)
    for k in "444": cmd("key " + k + "\\n"); time.sleep(0.3)
    time.sleep(4)


def cell(gx, gy):   # window coordinates of a map cell (the game's own grid x 0..50, y 0..12)
    return (12 + (gx + 1) * 32 + 16, 82 + (gy + 1) * 32 + 16)


def find(scr, chars):   # -> [(gx, gy, ch)] of map cells holding any of `chars`
    return [(c - 1, r - 6, scr[r][c]) for r in range(6, 19) for c in range(1, 52) if scr[r][c] in chars]


def click(gx, gy):
    x, y = cell(gx, gy); cmd(f"uiclick {x} {y}")


cheb = lambda a, b: max(abs(a[0] - b[0]), abs(a[1] - b[1]))
