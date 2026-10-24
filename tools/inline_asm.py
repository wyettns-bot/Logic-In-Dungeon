#!/usr/bin/env python3
"""inline_asm.py - paste every %include into one file: game.asm -> logicindungeon.asm"""
import os as _os
_os.chdir(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))   # run from anywhere: work in the game folder
import re, sys, os
def expand(path, seen):
    out = []
    for line in open(path):
        m = re.match(r'\s*%include\s+"([^"]+)"', line)
        if m and os.path.exists(m.group(1)):
            name = m.group(1)
            out.append(f"; ===== begin {name} =====\n")
            out += expand(name, seen)
            out.append(f"; ===== end {name} =====\n")
        else:
            out.append(line)
    return out
src = sys.argv[1] if len(sys.argv) > 1 else "game.asm"
dst = sys.argv[2] if len(sys.argv) > 2 else "logicindungeon.asm"
open(dst, "w").writelines(expand(src, set()))
print("wrote", dst)
