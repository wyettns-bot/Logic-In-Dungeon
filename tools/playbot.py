"""playbot.py - plays the real game in a terminal emulator and logs how it goes.
usage: CLS=1 MAXFLOOR=9 python3 playbot.py
"""
import os as _os
_os.chdir(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))   # run from anywhere: work in the game folder
import os, sys, time, re, collections
exec(open(_os.path.join('tools', 'h.py')).read())

CLS = os.environ.get("CLS", "1")
MAXFLOOR = int(os.environ.get("MAXFLOOR", "9"))
MAIN = {"1": "1", "2": "2", "3": "4"}[CLS]          # stat point: STR / DEX / INT
LOG = []
def log(*a):
    s = " ".join(str(x) for x in a); LOG.append(s); print(s, flush=True)

TRUTH = {"AND": 8, "OR": 14, "XOR": 6, "NAND": 7, "NOR": 1, "XNOR": 9}
LETTER = {"A": "AND", "V": "OR", "X": "XOR", "a": "NAND", "v": "NOR", "E": "XNOR"}

def grid():
    g = []
    for r in range(7, 20):
        line = row(r)
        g.append(line[1:52] if len(line) >= 52 else line[1:].ljust(51))
    return g
def floor_no():
    m = re.search(r"Floor:\s*(\d+)", row(3)); return int(m.group(1)) if m else 0
def hp():
    m = re.search(r"HP:\s*(\d+)/(\d+)", row(3)); return (int(m.group(1)), int(m.group(2))) if m else (0, 1)
def level():
    m = re.search(r"Lv:(\d+)(\*?)", row(1)); return (int(m.group(1)), m.group(2) == "*") if m else (0, False)
def me():
    g = grid()
    for y, l in enumerate(g):
        x = l.find("@")
        if x >= 0: return (x, y)
    return None
ENEMY = set("GSOMBKDdYJjTtUuFHZP")
def enemies():
    g = grid(); out = []
    for y, l in enumerate(g):
        for x, ch in enumerate(l):
            if ch in ENEMY and not (ch in "AVXaEvBM" and False): out.append((x, y))
    return out
def items_on_map():
    g = grid(); out = []
    for y, l in enumerate(g):
        for x, ch in enumerate(l):
            if ch in "!/" or (ch == "]" and not (x >= 2 and l[x - 2] == "[")) or ch == "?": out.append((x, y))
    return out
def torches():
    g = grid(); out = []
    for y, l in enumerate(g):
        for x in range(len(l) - 2):
            if l[x] == "[" and l[x + 1] in "01" and l[x + 2] == "]": out.append((x, y, int(l[x + 1])))
    return out
def walkable(ch): return ch in ".*+x-=:|!/?" or ch == "]"
def cheb(a, b): return max(abs(a[0] - b[0]), abs(a[1] - b[1]))
def mclick(x, y, t=0.25): click(x + 2, y + 7, t)

def bfs(start, goal_fn, avoid_items=False):
    g = grid(); tor = set()
    for (tx, ty, _) in torches():
        for k in range(3): tor.add((tx + k, ty))
    prev = {start: None}; q = collections.deque([start])
    while q:
        c = q.popleft()
        if goal_fn(c) and c != start:
            path = []
            while c != start: path.append(c); c = prev[c]
            return path[::-1]
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (c[0] + dx, c[1] + dy)
                if n in prev or not (0 <= n[0] < 51 and 0 <= n[1] < 13): continue
                ch = g[n[1]][n[0]]
                if n in tor or not walkable(ch): continue
                prev[n] = c; q.append(n)
    return None

def straight_ok(a, b):              # does the game's straight walk from a to b avoid obstacles?
    g = grid(); x, y = a; tor = set((tx + k, ty) for (tx, ty, _) in torches() for k in range(3))
    while (x, y) != b:
        x += (b[0] > x) - (b[0] < x); y += (b[1] > y) - (b[1] < y)
        if (x, y) in tor or not walkable(g[y][x]) and (x, y) != b: return False
    return True

def walk_path(path, wait=0.15):     # click the farthest point along the path the game can walk straight to
    p = me()
    if not p or not path: return
    best = path[0]
    for c in path[:10]:
        if straight_ok(p, c): best = c
    mclick(*best, wait)
    for _ in range(12):             # let it walk
        pump(0.1)
        if me() == best: break

def in_combat(): return "COMBAT" in mode() or "Turn-based - your" in mode()
def my_turn(): return "your turn" in mode()
def enemy_turn(): return "enemy turn" in mode() or "others" in mode()

def bag():
    out = []
    for r in range(7, 19):
        l = row(r)[55:80]
        m = re.match(r"\[(.)\] (.{15}).?([+#]?)(\*?)", l)
        if m and m.group(2).strip(): out.append((m.group(1), m.group(2).strip(), l[20:21], l[21:22] == "*"))
    return out

STATS = collections.Counter()
def use_potion():
    if CLS == "3" and "BAG" not in row(6): send("i", 0.2)
    for k, name, rar, worn in bag():
        if "Potion" in name:
            send(k, 0.3); STATS["potions"] += 1; log("   drank", name, "->", hp())
            break
    if CLS == "3" and "BAG" in row(6): send("i", 0.2)

def try_equip_new():
    if CLS == "3" and "BAG" not in row(6): send("i", 0.2)
    for k, name, rar, worn in bag():
        if rar in "+#" and not worn and name not in tried:
            tried.add(name)
            send(k, 0.3)
            ok = any(n == name and w for kk, n, r, w in bag())
            log("   equip", name, "(rare)" if rar == "+" else "(LEGENDARY)", "->", "worn" if ok else msg()[:60])
            if ok: STATS["equipped"] += 1
    if CLS == "3" and "BAG" in row(6): send("i", 0.2)
tried = set()

def spend_points():
    lv, pts = level()
    while pts:
        send("u", 0.2); send(MAIN, 0.3)
        nlv, pts2 = level()
        if pts2 == pts: break
        pts = pts2

def attack_round():
    """my turn in combat: move toward the nearest enemy, attack / cast, end the turn"""
    p = me(); E = enemies()
    if not p or not E: return
    n = min(E, key=lambda e: cheb(p, e))
    h, hm = hp()
    if h < hm * 0.35: use_potion()
    if CLS == "3" and cheb(p, n) <= 14:          # the wizard casts Firebolt
        if "BAG" in row(6): send("i", 0.2)
        send("1", 0.2); aim_click(n[0] + 2, n[1] + 7, 0.5)
        m = msg()
        if "Firebolt" in m: STATS["casts"] += 1
        endturn(); return
    if CLS == "2" and "HIDDEN" not in row(21):      # Cunning Action: step away, hide, step back, sneak attack
        away = bfs(p, lambda c: min(cheb(c, e) for e in enemies()) >= 2)
        if away and len(away) <= 3:
            walk_path(away[:2]); send("h", 0.3)
            if "HIDDEN" in row(21): STATS["hides"] += 1
            p = me()
    if cheb(p, n) > 1:
        path = bfs(p, lambda c: cheb(c, n) <= 1)
        if path: walk_path(path)
        p = me()
    for _ in range(4):                            # every attack you have
        if not p: break
        E = enemies()
        if not E: break
        n = min(E, key=lambda e: cheb(p, e))
        if cheb(p, n) > 1: break
        before = msg() + ("HIDDEN" if "HIDDEN" in row(21) else "")
        mclick(*n, 0.25)
        m = msg()
        if "already acted" in m or m == before: break
        if "You hit" in m:
            STATS["hits"] += 1
            if "HIDDEN" in before: STATS["sneak"] += 1
            if "HIDDEN" in before or STATS.get("_hid"): pass
    endturn()

def fight():
    t0 = time.time()
    while enemies() and time.time() - t0 < 240:
        if "You died" in "".join(screen.display): return False
        if enemy_turn(): pump(0.3); continue
        if in_combat() and my_turn(): attack_round(); continue
        p = me(); E = enemies()
        if not p or not E: pump(0.2); continue
        if CLS == "2" and "HIDDEN" not in row(21) and min(cheb(p, e) for e in E) > 2:
            send("h", 0.3); STATS["hides"] += 1         # sneak up on them
        n = min(E, key=lambda e: cheb(p, e))
        if cheb(p, n) <= 1:                         # right next to it, nobody fighting yet: strike first
            mclick(*n, 0.3); continue
        path = bfs(p, lambda c: cheb(c, n) <= 1)
        if path: walk_path(path)
        else: pump(0.3)
    return True

def collect_items():
    for _ in range(6):
        p = me(); I = items_on_map()
        if not p or not I: return
        tgt = min(I, key=lambda i: cheb(p, i))
        path = bfs(p, lambda c: c == tgt)
        if not path: return
        for _ in range(6):
            walk_path(path); p = me()
            if p == tgt: break
            path = bfs(p, lambda c: c == tgt) if p else None
            if not path: break
        m = msg()
        if "pick up" in m or "learn" in m:
            log("   ", m[:80]); STATS["items"] += 1
            if "rare" in m: STATS["rare"] += 1
            if "LEGENDARY" in m: STATS["legendary"] += 1

def goto(tgt):
    for _ in range(10):
        p = me()
        if p == tgt: return True
        path = bfs(p, lambda c: c == tgt) if p else None
        if not path: return False
        walk_path(path)
        if in_combat() and my_turn() and me() != tgt: endturn()
    return me() == tgt

def solve_pairs():
    T = torches()
    if not T: return True
    g = grid()
    gate = None
    # the Warden shows his gate in the middle of his body
    for y, l in enumerate(g):
        for x, ch in enumerate(l):
            if ch in "AVX" and x > 0 and l[x - 1] == "M": gate = LETTER[ch]
    if not gate:                                  # read the plaque
        goto((49, 8)) or goto((49, 10))
        mclick(50, 9, 0.5); m = msg()
        gate = m.split(" ")[0] if m.split(" ")[0] in TRUTH else None
        need_all = "every true pair" in m
    else:
        need_all = False
    if not gate: return False
    tt = TRUTH[gate]
    accepted = [i for i in range(4) if tt >> i & 1]
    pairs = sorted(set((x, y) for (x, y, _) in [(t[0] - (3 if (t[0], t[1]) not in [(u[0], u[1]) for u in T if True] else 0), t[1], 0) for t in T]))
    # group torches into pairs: same row, left x is the smaller
    rows = collections.defaultdict(list)
    for (x, y, b) in T: rows[y].append((x, b))
    plan = []
    keys = sorted(rows)
    for i, y in enumerate(keys):
        (ax, ab), (bx, bb) = sorted(rows[y])[:2]
        want = accepted[i] if need_all else accepted[0]
        plan.append(((ax, y), want >> 1)); plan.append(((bx, y), want & 1))
    for (tx, ty), w in plan:
        cur = next(b for (x, y, b) in torches() if (x, y) == (tx, ty)) if any((x, y) == (tx, ty) for (x, y, _) in torches()) else None
        if cur is None or cur == w: continue
        for sy in (ty + 1, ty - 1):
            if 0 <= sy < 13 and goto((tx + 1, sy)): break
        mclick(tx + 1, ty, 0.4)
    m = msg()
    return "opens" in m or "shield breaks" in m or ">" in "".join(g[y][50] for y in range(5, 8))

def door_open(): return ">" in "".join(grid()[y][50] for y in range(5, 8))

def play():
    pump(0.5); send("\n"); send(CLS + "\n"); send("y\n")
    for k in "444": send(k + "\n", 0.2)
    pump(0.8)
    last_floor = 0; t_start = time.time()
    while True:
        f = floor_no()
        if "You died" in "".join(screen.display) or not me() and "died" in msg():
            log("DIED on floor", last_floor); return
        if f != last_floor:
            lv, _ = level(); log(f"== floor {f}  Lv {lv}  HP {hp()}  XP {row(1)[36:56].strip()}  t={int(time.time()-t_start)}s  {msg()[:70]}")
            last_floor = f
            if f > MAXFLOOR: log("reached the floor limit"); return
            if f >= 16 or f in (12, 15, 17, 21, 26, 30):
                log("(circuit / big-boss floor: the bot stops here)"); return
        alive = fight()
        if not alive: log("DIED on floor", f); return
        spend_points(); collect_items(); try_equip_new(); spend_points()
        h, hm = hp()
        if h < hm * 0.5: use_potion()
        if not door_open():
            solved = solve_pairs()
            if not door_open():
                pump(0.5)
                if not door_open():
                    log("   could not open the door:", msg()[:80]);
                    solve_pairs()
                    if not door_open(): log("   stuck on floor", f); return
        goto((49, 6)); mclick(50, 6, 1.0); pump(0.5)
        if floor_no() == f:
            mclick(50, 6, 1.0); pump(0.8)

try:
    play()
finally:
    lv, _ = level()
    log("SUMMARY class", CLS, "floor", floor_no(), "level", lv, "HP", hp(), "row1:", row(1)[:60].strip())
    log("   stats:", row(4)[:60].strip(), "| AC/weapon:", row(1)[:34].strip())
    log("   counters:", dict(STATS))
    log("   bag:", [(n, r) for k, n, r, w in bag()])
