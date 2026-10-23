#!/usr/bin/env python3
"""Logic In Dungeon - the short pieces of music, made from code (no samples).
   python3 music_synth.py OUTDIR [boss_generic victory game_over level_up floor_clear]
Uses the oscillators/filters/reverb from sfx_synth.py. Writes stereo Ogg Vorbis (needs ffmpeg)."""
import sys, os, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile
import sfx_synth as S
from sfx_synth import SR, osc, noise, lp, hp, env, sweep, bell

def hz(note):
    """'A4', 'C#5', 'Bb3' -> frequency"""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note[0]]; i = 1
    if note[i:i + 1] == "#": n += 1; i += 1
    elif note[i:i + 1] == "b": n -= 1; i += 1
    return 440.0 * 2 ** ((n + 12 * (int(note[i:]) + 1) - 69) / 12)

class Track:
    """a stereo buffer you drop notes into at a time (seconds) with a pan (-1 left .. 1 right)"""
    def __init__(self, dur):
        self.L = np.zeros(int(SR * dur) + SR); self.R = np.zeros_like(self.L)
    def add(self, sig, t, pan=0.0, gain=1.0):
        s = int(SR * t); e = min(len(self.L), s + len(sig)); sig = sig[:e - s] * gain
        self.L[s:e] += sig * np.sqrt((1 - pan) / 2) * 1.41
        self.R[s:e] += sig * np.sqrt((1 + pan) / 2) * 1.41

# ---------------- instruments ----------------
def brass(f, d, vel=1.0):
    a = min(0.05, d * 0.3)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * S.t_axis(d)) * np.clip(S.t_axis(d) / 0.3 - 0.5, 0, 1)
    x = sum(osc(f * c * vib, d, "saw") for c in (0.997, 1.0, 1.004)) / 3 + 0.25 * osc(f * vib, d, "square")
    fenv = env(d, a, max(d * 0.6, 0.05), s=0.35, curve=1.5)
    bright, dark = lp(x, 3200), lp(x, 650)
    y = dark + (bright - dark) * fenv
    return y * env(d, a, d, s=0.75, r=min(0.12, d * 0.3)) * vel

def strings(f, d, vel=1.0, bright=2400):
    t = S.t_axis(d)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.5 * t + S.rng.uniform(0, 6))
    x = sum(osc(f * (1 + c) * vib, d, "saw") for c in (-0.006, -0.002, 0.0, 0.003, 0.007)) / 5
    x = lp(hp(x, 120), bright, 2)
    return x * env(d, min(0.3, d * 0.4), d, s=1.0, r=min(0.5, d * 0.4)) * vel

def flute(f, d, vel=1.0, breath=0.06):
    t = S.t_axis(d)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5 * t) * np.clip(t / 0.4, 0, 1)
    x = osc(f * vib, d) + 0.18 * osc(2 * f * vib, d) + 0.05 * osc(3 * f * vib, d)
    air = lp(hp(noise(d), 1500), 5000) * breath
    return (x + air) * env(d, 0.06, d, s=1.0, r=min(0.25, d * 0.4)) * vel

def bass(f, d, vel=1.0):
    x = osc(f, d, "saw") * 0.7 + osc(f * 0.5, d, "square") * 0.3
    return lp(x, 700) * env(d, 0.005, d * 0.9, s=0.5, r=0.04, curve=2) * vel

def kick(vel=1.0):
    d = 0.35
    return S.mix(osc(sweep(130, 42, d), d) * env(d, 0.001, 0.3, curve=2.5) * 1.2, lp(noise(0.02), 3000) * env(0.02, 0.0005, 0.015) * 0.4) * vel

def snare(vel=1.0):
    d = 0.25
    body = osc(sweep(230, 180, d), d) * env(d, 0.001, 0.08) * 0.6
    rattle = S.bandpass_sweep(noise(d), 2500, 1800, q=1.2, blocks=8) * env(d, 0.001, 0.18, curve=2)
    return (body + rattle) * vel

def tom(f, vel=1.0):
    d = 0.45
    return S.mix(osc(sweep(f * 1.3, f, d), d) * env(d, 0.001, 0.4, curve=2), lp(noise(0.03), 2000) * env(0.03, 0.0005, 0.02) * 0.3) * vel

def timpani(f, vel=1.0, d=1.6):
    tt = S.t_axis(d)[:len(osc(f, d))]
    x = osc(sweep(f * 1.02, f, d), d) + 0.4 * osc(f * 1.5, d) * np.exp(-tt * 4) + 0.2 * osc(f * 2.0, d) * np.exp(-tt * 3)
    hit = lp(noise(0.04), 1500) * env(0.04, 0.0005, 0.03) * 0.5
    return S.mix(x * env(d, 0.002, d, curve=2.2), hit) * vel

def cymbal(vel=1.0, d=2.0):
    return hp(noise(d), 5000) * env(d, 0.002, d, curve=2.5) * 0.5 * vel

def finish_stereo(tr, length=None, loop=False, tail=3.0, peak_db=-1.5, verb=(1.4, 0.25)):
    L, R = tr.L, tr.R
    L = S.reverb(L, verb[0], verb[1], 5000); R = S.reverb(R, verb[0], verb[1], 5200)
    n = int(SR * length) if length else len(L)
    if loop:                                      # wrap the reverb tail onto the start = a seamless loop
        t = int(SR * tail)
        L[:t] += L[n:n + t]; R[:t] += R[n:n + t]
    L, R = L[:n], R[:n]
    if not loop:
        f = int(SR * 0.02); L[-f:] *= np.linspace(1, 0, f); R[-f:] *= np.linspace(1, 0, f)
    m = max(np.max(np.abs(L)), np.max(np.abs(R)))
    g = 10 ** (peak_db / 20) / m
    return np.stack([np.tanh(L * g * 1.1) / np.tanh(1.1), np.tanh(R * g * 1.1) / np.tanh(1.1)], axis=1) * 10 ** (peak_db / 20)

# ---------------- the pieces ----------------
def boss_generic():
    """D minor, 132 BPM, 32 bars: drums, driving bass, brass stabs, strings, a brass theme. Loops seamlessly."""
    bpm = 132; b = 60 / bpm; bar = 4 * b; bars = 32
    tr = Track(bars * bar + 4)
    prog = [("D3", ("D4", "F4", "A4")), ("Bb2", ("D4", "F4", "Bb4")), ("C3", ("E4", "G4", "C5")), ("A2", ("C#4", "E4", "A4"))]
    theme = [  # (note, beats) per 2-bar chord
        [("A4", 1), ("D5", 1), ("F5", 1.5), ("E5", 0.5), ("D5", 2), ("A4", 2)],
        [("Bb4", 1), ("D5", 1), ("F5", 2), ("E5", 1), ("D5", 1), ("C5", 2)],
        [("C5", 1), ("E5", 1), ("G5", 1.5), ("F5", 0.5), ("E5", 2), ("C5", 2)],
        [("C#5", 1), ("E5", 1), ("A5", 3), ("G5", 1), ("E5", 2)]]
    for k in range(bars):
        t0 = k * bar; root, chord = prog[(k // 2) % 4]
        # drums
        for beat in range(4):
            tb = t0 + beat * b
            if beat in (0, 2): tr.add(kick(), tb, 0, 0.9)
            if beat in (1, 3): tr.add(snare(), tb, 0.1, 0.55)
        tr.add(kick(0.7), t0 + 3.5 * b, 0, 0.8)
        if k % 8 == 7:                                     # a tom fill into the next phrase
            for j, f in enumerate((180, 150, 120, 95)): tr.add(tom(f), t0 + (2 + j * 0.5) * b, -0.4 + j * 0.25, 0.7)
        if k % 8 == 0: tr.add(cymbal(), t0, 0.3, 0.6)
        # driving bass: eighth notes, octave on the off-beats
        for e in range(8):
            f = hz(root) * (2 if e % 2 else 1)
            tr.add(bass(f, b / 2 * 0.9), t0 + e * b / 2, 0, 0.55)
        # strings hold the chord over 2 bars
        if k % 2 == 0:
            for j, n in enumerate(chord): tr.add(strings(hz(n), 2 * bar), t0, -0.5 + j * 0.5, 0.22)
        # brass stabs on 1 and the and-of-2
        for sb in (0, 1.5):
            for n in chord: tr.add(brass(hz(n) / 2, b * 0.45, 0.9), t0 + sb * b, 0.2, 0.16)
        # the brass theme in bars 9-16 and 25-32
        if (8 <= k < 16 or 24 <= k < 32) and k % 2 == 0:
            tt = t0
            for n, beats in theme[(k // 2) % 4]:
                tr.add(brass(hz(n), beats * b * 0.95), tt, -0.15, 0.32); tt += beats * b
    return finish_stereo(tr, bars * bar, loop=True, tail=3.0, verb=(1.6, 0.25))

def victory():
    """C major fanfare: timpani roll, brass call, strings swell, a long final chord."""
    bpm = 96; b = 60 / bpm
    tr = Track(16)
    for j in range(16):                                    # timpani roll, building
        tr.add(timpani(hz("G2"), 0.3 + j * 0.04, 0.5), j * b / 4, -0.2, 0.8)
    tr.add(timpani(hz("C2"), 1.0), 4 * b, 0, 1.0); tr.add(cymbal(1.0, 3.0), 4 * b, 0.3, 0.8)
    call = [("G4", 0.333), ("C5", 0.333), ("E5", 0.334), ("G5", 1.5), ("E5", 0.5), ("G5", 1), ("C6", 3)]
    t = 4 * b
    for n, beats in call: tr.add(brass(hz(n), beats * b * 0.95), t, -0.1, 0.45); t += beats * b
    harmony = [(("C4", "E4", "G4"), 0, 3), (("F4", "A4", "C5"), 3, 2), (("G4", "B4", "D5"), 5, 2), (("C4", "E4", "G4", "C5"), 7, 8)]
    for ch, st, ln in harmony:
        for j, n in enumerate(ch):
            tr.add(strings(hz(n), ln * b + 0.5), 4 * b + st * b, -0.5 + j * 0.33, 0.25)
            tr.add(brass(hz(n) / 2, min(ln, 2) * b, 0.7), 4 * b + st * b, 0.25, 0.12)
        tr.add(timpani(hz("C2") if ch[0][0] == "C" else hz("G2") if ch[0][0] == "G" else hz("F2"), 0.8), 4 * b + st * b, 0, 0.8)
    tr.add(cymbal(0.8, 4.0), 11 * b, -0.3, 0.6)
    for n in ("C3", "G3"): tr.add(bass(hz(n), 8 * b, 0.8) * np.linspace(1, 0, int(SR * 8 * b)), 11 * b, 0, 0.4)
    return finish_stereo(tr, 11 * b + 8 * b + 1.5, verb=(2.0, 0.3))

def game_over():
    """A minor, slow: low strings, a lonely flute falling, a dark final chord."""
    b = 1.0
    tr = Track(11)
    chords = [(("A2", "E3", "A3", "C4"), 0, 2), (("F2", "C3", "A3"), 2, 2), (("D2", "A2", "F3"), 4, 1.5), (("E2", "B2", "G#3"), 5.5, 1.5), (("A1", "E2", "A2", "C3"), 7, 3.5)]
    for ch, st, ln in chords:
        for j, n in enumerate(ch): tr.add(strings(hz(n), ln * b + 0.6, bright=1100), st * b, -0.4 + j * 0.27, 0.2)
    mel = [("E5", 1), ("D5", 0.5), ("C5", 0.5), ("B4", 1), ("A4", 1), ("C5", 0.75), ("B4", 0.75), ("G#4", 1), ("A4", 3)]
    t = 0.5
    for n, beats in mel: tr.add(flute(hz(n), beats * b * 0.97, breath=0.02), t, 0.15, 0.7); t += beats * b
    tr.add(timpani(hz("A1"), 0.9, 2.5), 7 * b, 0, 0.9)
    return finish_stereo(tr, 10.8, verb=(2.2, 0.35))

def level_up():
    tr = Track(3)
    for j, n in enumerate(("C5", "E5", "G5")): tr.add(brass(hz(n), 0.14), j * 0.09, -0.2 + j * 0.2, 0.5)
    for n in ("C5", "E5", "G5", "C6"): tr.add(brass(hz(n), 1.2), 0.27, 0, 0.25)
    tr.add(timpani(hz("C2"), 0.7, 1.2), 0.27, 0, 0.7); tr.add(cymbal(0.6, 1.6), 0.27, 0.3, 0.5)
    return finish_stereo(tr, 2.2, verb=(1.2, 0.25))

def floor_clear():
    tr = Track(3)
    for n in ("D4", "G4", "B4"): tr.add(brass(hz(n), 0.22), 0, 0, 0.3)
    for n in ("C4", "E4", "G4", "C5"): tr.add(brass(hz(n), 0.9), 0.26, 0, 0.28)
    tr.add(timpani(hz("G2"), 0.6, 0.6), 0, 0, 0.6); tr.add(timpani(hz("C2"), 0.8, 1.2), 0.26, 0, 0.8)
    return finish_stereo(tr, 1.8, verb=(1.0, 0.22))

PIECES = {"boss_generic": boss_generic, "victory": victory, "game_over": game_over, "level_up": level_up, "floor_clear": floor_clear}

if __name__ == "__main__":
    out = sys.argv[1]; names = sys.argv[2:] or list(PIECES)
    os.makedirs(out, exist_ok=True)
    for name in names:
        S.rng = np.random.default_rng(sum(map(ord, name)))
        x = PIECES[name]()
        tmp = os.path.join(tempfile.gettempdir(), name + "_mus.wav")
        wavfile.write(tmp, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", os.path.join(out, name + ".ogg")], check=True)
        print(f"{name:14s} {len(x) / SR:6.1f}s")
