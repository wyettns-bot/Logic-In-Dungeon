#!/usr/bin/env python3
"""testbuild.py - build a TEST copy of the game with cheats and shortcuts, for the test bots.

    python3 tools/tests/testbuild.py NAME FLOOR [options...]

writes tools/tests/build/NAME. The real game is never touched: the sources are copied to a
temporary folder, patched there and assembled. Options:

    hp250     start with 250 HP (all classes)
    wiz       the wizard knows every spell and casting is free
    unbound   on floor 30 the King rises as the Unbound at once
    cycle     the Unbound changes form after every boss turn
    solve     the '!' key solves the current boss puzzle (sets the torches right)
    weak      the Unbound hits for 1-1
    god       the player can't die (HP refills instead)
    nofight   boss rooms never start the fight (enemies keep exploring)
    stat      start with 3 stat points
    weakwardens  Wardens have 3-4 base HP (to test what happens when one dies)
    frail     demo mode: each demo room starts the hero at 1 HP (to test that you can't die)
    frailunbound  the Unbound has 1 HP (to test what happens when he dies)

Every patch checks that the code it changes is still there; if the game's source has moved on,
the build stops with a message instead of silently testing the wrong thing.
"""
import os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BUILD = os.path.join(HERE, "build")


def patch(src, fname, old, new, what):
    p = os.path.join(src, fname)
    s = open(p).read()
    if old not in s:
        sys.exit(f"testbuild: can't apply '{what}' - {fname} has changed (looked for: {old.splitlines()[0].strip()!r})")
    open(p, "w").write(s.replace(old, new, 1))


def build(name, floor, opts):
    os.makedirs(BUILD, exist_ok=True)
    src = tempfile.mkdtemp(prefix="lid_test_")
    try:
        for f in os.listdir(ROOT):
            if f.endswith((".asm", ".inc")) and f != "logicindungeon.asm":
                shutil.copy(os.path.join(ROOT, f), src)
        patch(src, "game.asm", "    mov dword [floorCount], 1\n",
              f"    mov dword [floorCount], {floor}   ; TEST\n", "start floor")
        if "hp250" in opts:
            p = os.path.join(src, "game.asm"); s = open(p).read()
            s2 = re.sub(r"^basehp db .*$", "basehp db 250, 250, 250", s, count=1, flags=re.M)
            if s2 == s: sys.exit("testbuild: can't apply 'hp250'")
            open(p, "w").write(s2)
        if "wiz" in opts:
            patch(src, "features.inc", """    cmp byte [spellTable+ebx+SPELL_MANA_COST], 0
    jne .n                      ; you start with the cantrips only""", """    jmp .ok_all                 ; TEST: every spell
.ok_all:""", "wiz: every spell")
            p = os.path.join(src, "progress.inc"); s = open(p).read()
            i = s.index("spell_cost:"); j = s.index("\n", i)
            open(p, "w").write(s[:j + 1] + "    xor eax, eax                ; TEST: free\n    ret\n" + s[j + 1:])
        if "unbound" in opts:
            patch(src, "bosses.inc", """.king:
    cmp dword [bossRoom], 2
    jne .note""", """.king:
    cmp dword [bossRoom], 2
    jne .note
    cmp dword [isUnbound], 0     ; TEST: rise at once
    jne .tk
    call king_rise
.tk:""", "unbound")
        if "cycle" in opts:
            patch(src, "bosses.inc", "unbound_round:\n    call coin",
                  "unbound_round:\n    mov dword [uSwitch], 1      ; TEST: a new form every boss turn\n    call coin", "cycle")
        if "weak" in opts:
            p = os.path.join(src, "game_assets.asm"); s = open(p).read()
            s2 = re.sub(r"(\tunbound db \d+,\d+, )\d+,\d+,", r"\g<1>1,1,", s, count=1)
            if s2 == s: sys.exit("testbuild: can't apply 'weak'")
            open(p, "w").write(s2)
        if "weakwardens" in opts:
            p = os.path.join(src, "game_assets.asm"); s = open(p).read()
            s2 = re.sub(r"\tminiboss db \d+,\d+,", "\tminiboss db 3,4,", s, count=1)
            if s2 == s: sys.exit("testbuild: can't apply 'weakwardens'")
            open(p, "w").write(s2)
        if "frail" in opts:
            patch(src, "demo.inc", """.full:
    mov eax, [playerMaxHP]
    mov [playerHP], eax""", """.full:
    mov dword [playerHP], 1     ; TEST frail""", "frail")
        if "frailunbound" in opts:
            p = os.path.join(src, "game_assets.asm"); s = open(p).read()
            s2 = re.sub(r"(\tunbound db )\d+,\d+,", r"\g<1>1,1,", s, count=1)
            if s2 == s: sys.exit("testbuild: can't apply 'frailunbound'")
            open(p, "w").write(s2)
        if "god" in opts:
            patch(src, "enemies.inc", """.chk:
    cmp dword [playerHP], 0
    jg .alive
    mov dword [playerHP], 0""", """.chk:
    cmp dword [playerHP], 0
    jg .alive
    mov dword [playerHP], 250   ; TEST god
    jmp .alive""", "god (enemy turn)")
            patch(src, "bosses.inc", """player_dead_check:                  ; a boss rule hurt you outside the attack line
    cmp dword [playerHP], 0
    jg .ok""", """player_dead_check:                  ; a boss rule hurt you outside the attack line
    cmp dword [playerHP], 0
    jg .ok
    mov dword [playerHP], 250   ; TEST god
    jmp .ok""", "god (boss rules)")
        if "nofight" in opts:
            patch(src, "room.inc", "    call start_combat               ; boss rooms start the fight at once",
                  "    nop                             ; TEST: the fight never starts", "nofight")
        if "stat" in opts:
            patch(src, "progress.inc", "    mov dword [statPoints], 0\n",
                  "    mov dword [statPoints], 3   ; TEST\n", "stat")
        if "solve" in opts:
            patch(src, "game.asm", """    cmp al, 't'
    je .tb""", """    cmp al, '!'
    jne .nosv
    call test_solve             ; TEST: solve the current boss puzzle
    jmp .next
.nosv:
    cmp al, 't'
    je .tb""", "solve key")
            with open(os.path.join(src, "game.asm"), "a") as f:
                f.write(open(os.path.join(HERE, "test_solve.asm")).read())
        out = os.path.join(BUILD, name)
        for cmd in (["nasm", "-f", "elf32", "CC.asm", "-o", "CC.o"], ["nasm", "-f", "elf32", "game.asm", "-o", "game.o"],
                    ["ld", "-m", "elf_i386", "game.o", "CC.o", "-o", out]):
            subprocess.run(cmd, cwd=src, check=True)
        return out
    finally:
        shutil.rmtree(src, ignore_errors=True)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    print("built", build(sys.argv[1], int(sys.argv[2]), set(sys.argv[3:])))
