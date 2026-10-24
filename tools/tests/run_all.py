#!/usr/bin/env python3
"""run_all.py - run every test bot and print a summary.  (Takes about 15-20 minutes.)

    python3 tools/tests/run_all.py            every boss, the Unbound's forms, the Keeper's Wardens
    python3 tools/tests/run_all.py 12 21      just those boss floors

Needs nasm, gcc + raylib, and xvfb-run. If raylib is built from source, set RAYLIB_DIR.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_test, unbound_test, warden_death_test

floors = [int(a) for a in sys.argv[1:]] or [4, 8, 12, 15, 17, 21, 26, 30]
results = []
for f in floors:
    results.append((f"boss floor {f}", boss_test.run(f)))
if not sys.argv[1:]:
    results.append(("Unbound forms", unbound_test.run()))
    results.append(("Keeper's Wardens", warden_death_test.run()))
print("\n==== summary ====")
for name, ok in results:
    print(f"  {'PASS' if ok else 'FAIL'}  {name}")
bad = sum(1 for _, ok in results if not ok)
print(f"{len(results) - bad}/{len(results)} passed")
sys.exit(1 if bad else 0)
