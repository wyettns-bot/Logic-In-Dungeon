#!/usr/bin/env python3
"""Logic In Dungeon - procedural sound effects.
Every sound is built from scratch: oscillators, noise, filters, envelopes,
plus a small 'stone room' reverb. Run: python3 sfx_synth.py OUTDIR
"""
import sys, os
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(7)

# ---------- building blocks ----------
def t_axis(dur):            return np.arange(int(SR * dur)) / SR
def noise(dur):             return rng.uniform(-1, 1, int(SR * dur))

def env(dur, a=0.005, d=0.1, s=0.0, r=0.0, curve=3.0):
    """attack / decay-to-sustain / release; exponential-ish decay."""
    n = int(SR * dur); e = np.zeros(n)
    na, nd = int(SR * a), int(SR * d)
    e[:na] = np.linspace(0, 1, na) if na else 1
    k = np.linspace(0, 1, max(nd, 1))
    e[na:na + nd] = (s + (1 - s) * (1 - k) ** curve)[:max(0, min(nd, n - na))]
    e[na + nd:] = s
    if r:
        nr = int(SR * r); e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e

def osc(freq, dur, shape="sine"):
    """freq may be a number or an array (for sweeps)."""
    f = np.broadcast_to(freq, int(SR * dur)).astype(float)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":   return np.sin(ph)
    if shape == "square": return np.sign(np.sin(ph))
    if shape == "saw":    return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == "tri":    return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1

def sweep(f0, f1, dur, curve="exp"):
    k = np.linspace(0, 1, int(SR * dur))
    return f0 * (f1 / f0) ** k if curve == "exp" else f0 + (f1 - f0) * k

def bandpass_sweep(x, f0, f1, q=2.0, blocks=64):
    """time-varying band-pass by processing in short overlapping blocks."""
    out = np.zeros_like(x); n = len(x); hop = n // blocks + 1
    win = np.hanning(hop * 2)
    for i in range(0, n, hop):
        fc = f0 * (f1 / f0) ** (i / n)
        bw = fc / q
        lo, hi = max(fc - bw / 2, 20), min(fc + bw / 2, SR / 2 - 100)
        b, a = signal.butter(2, [lo, hi], btype="band", fs=SR)
        seg = x[max(0, i - hop):i + hop]
        y = signal.lfilter(b, a, seg)
        w = win[:len(y)] if len(y) == len(win) else np.hanning(len(y))
        out[max(0, i - hop):max(0, i - hop) + len(y)] += y * w
    return out

def lp(x, fc, order=2): b, a = signal.butter(order, fc, fs=SR); return signal.lfilter(b, a, x)
def hp(x, fc, order=2): b, a = signal.butter(order, fc, btype="high", fs=SR); return signal.lfilter(b, a, x)

def crackle(dur, rate=60, length=0.004):
    """random fire pops."""
    x = np.zeros(int(SR * dur))
    for _ in range(int(rate * dur)):
        p = rng.integers(0, len(x) - int(SR * length))
        burst = noise(length) * env(length, 0.0005, length, curve=2)
        x[p:p + len(burst)] += burst * rng.uniform(0.3, 1)
    return hp(x, 1500)

def reverb(x, size=0.6, mix=0.25, damp=4000):
    """stone-room reverb: decaying filtered noise impulse response."""
    ir = noise(size) * np.exp(-np.linspace(0, 7, int(SR * size)))
    ir = lp(ir, damp); ir /= np.abs(ir).sum() ** 0.5 * 6
    wet = signal.fftconvolve(x, ir)[:len(x) + int(SR * size)]
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry * (1 - mix) + wet * mix

def pad(x, tail):  return np.concatenate([x, np.zeros(int(SR * tail))])
def mix(*parts):
    n = max(len(p) for p in parts); out = np.zeros(n)
    for p in parts: out[:len(p)] += p
    return out
def at(x, start, total):
    out = np.zeros(int(SR * total)); s = int(SR * start)
    out[s:s + len(x)] += x[:len(out) - s]; return out

def finish(x, peak_db=-1.0, sat=True):
    x = x - np.mean(x)
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 10 ** (-60 / 20))[0]
    x = x[:loud[-1] + int(SR * 0.02)]                  # trim silent tail
    fade = int(SR * 0.01); x[-fade:] *= np.linspace(1, 0, fade)
    if sat: x = np.tanh(x / np.max(np.abs(x)) * 1.2)  # gentle glue/saturation
    return x / np.max(np.abs(x)) * 10 ** (peak_db / 20)

# ---------- the sounds ----------
def ui_click():
    d = 0.06
    tick = hp(noise(d), 3000) * env(d, 0.0003, 0.008)
    blip = osc(sweep(1800, 1200, d), d) * env(d, 0.0005, 0.03) * 0.6
    return finish(reverb(mix(tick, blip), 0.15, 0.12), -3)

def torch_on():
    d = 1.1
    whoosh = bandpass_sweep(noise(d), 300, 2500, q=1.2) * env(d, 0.18, 0.7, curve=2)
    roar = lp(noise(d), 400) * env(d, 0.15, 0.9, s=0.15, r=0.3) * 0.8
    pops = crackle(d, 28) * env(d, 0.2, 0.2, s=0.6, r=0.4) * 0.22
    return finish(reverb(mix(whoosh, roar, pops), 0.5, 0.2))

def firebolt():
    d = 0.7
    body = bandpass_sweep(noise(d), 3500, 500, q=1.5) * env(d, 0.01, 0.55, curve=2)
    hiss = hp(noise(d), 5000) * env(d, 0.002, 0.15) * 0.5
    thump = osc(sweep(180, 60, d), d) * env(d, 0.002, 0.25) * 0.6
    pops = crackle(d, 80) * env(d, 0.02, 0.6) * 0.5
    return finish(reverb(mix(body, hiss, thump, pops), 0.5, 0.2))

def fireball():
    total = 2.4
    # 1) charge-up whoosh rising into the throw
    w = 0.45
    charge = bandpass_sweep(noise(w), 200, 3000, q=2) * env(w, 0.4, 0.05, curve=1)
    # 2) explosion: pitch-dropping sub + layered noise + debris crackle
    d = 1.9
    sub = osc(sweep(110, 32, d), d) * env(d, 0.003, 1.2, curve=2.5)
    blast = lp(noise(d), 900) * env(d, 0.002, 1.4, curve=3) * 1.3
    crack = hp(noise(d), 2000) * env(d, 0.001, 0.12) * 0.7
    debris = crackle(d, 50) * env(d, 0.05, 1.5, curve=2) * 0.4
    boom = mix(sub, blast, crack, debris)
    return finish(reverb(mix(at(charge, 0, total), at(boom, w, total)), 1.2, 0.3, 3000))

def ray_of_frost():
    d = 1.2
    tones = sum(osc(sweep(f, f * 0.8, d) * (1 + 0.004 * osc(6 + i, d)), d)
                for i, f in enumerate([2093, 2637, 3136, 3951, 4699]))
    tones *= (0.6 + 0.4 * osc(14, d)) * env(d, 0.03, 1.0, curve=2) / 5
    air = bandpass_sweep(noise(d), 9000, 4000, q=3) * env(d, 0.01, 0.9) * 0.7
    crystals = np.zeros(int(SR * d))
    for _ in range(25):                                   # tiny ice 'tinks'
        p = rng.integers(0, int(SR * (d - 0.1)))
        f = rng.uniform(4000, 8000); tl = 0.06
        crystals[p:p + int(SR * tl)] += osc(f, tl) * env(tl, 0.0005, 0.05) * rng.uniform(0.1, 0.35)
    return finish(reverb(mix(tones, air, crystals), 1.0, 0.35, 7000))

def warden_laser():
    d = 1.0
    f = sweep(900, 140, d) * (1 + 0.08 * osc(38, d))     # falling + wobble
    beam = osc(f, d, "saw") * 0.6 + osc(f * 1.01, d, "square") * 0.3
    beam = lp(beam, 4000) * env(d, 0.004, 0.8, s=0.1, r=0.15)
    zap = hp(noise(d), 4000) * env(d, 0.001, 0.08) * 0.8
    hum = osc(60, d, "saw") * env(d, 0.05, 0.9, curve=1) * 0.25
    return finish(reverb(mix(beam, zap, hum), 0.6, 0.25))

def note(freq, dur, bright=0.3):
    return (osc(freq, dur, "tri") + bright * osc(freq * 2, dur, "square") * 0.3
            + 0.2 * osc(freq * 3, dur)) * env(dur, 0.004, dur * 0.9, curve=2)

def level_up():
    total = 1.8
    # C5 E5 G5 C6 arpeggio, then a held chord
    seq = [(523.25, 0.00), (659.25, 0.09), (783.99, 0.18), (1046.5, 0.27)]
    parts = [at(note(f, 0.35), s, total) for f, s in seq]
    chord = sum(note(f, 1.2, 0.15) for f in (523.25, 659.25, 783.99, 1046.5)) / 3
    parts.append(at(chord * env(1.2, 0.01, 1.1, curve=1.5), 0.40, total))
    shine = hp(noise(total), 7000) * env(total, 0.4, 1.2) * 0.15
    return finish(reverb(mix(*parts, shine), 1.0, 0.3, 6000))

def taper(n, frac=0.35):
    """smooth fade over the last part so ringing tones never cut off with a click."""
    w = np.ones(n); k = int(n * frac); w[-k:] = np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return w

def bell(freq, dur):
    """FM bell: inharmonic partials ring like metal/crystal."""
    t = t_axis(dur)
    mod = 3.5 * freq * np.exp(-t * 3) * np.sin(2 * np.pi * freq * 1.4 * t)
    x = np.sin(2 * np.pi * freq * t + mod / freq) * np.exp(-t * 3.2)
    return x * taper(len(x))

def pickup_legendary():
    total = 2.2
    notes = [(783.99, 0.00), (987.77, 0.07), (1174.66, 0.14), (1567.98, 0.21), (1975.5, 0.30)]
    parts = [at(bell(f, 1.6) * 0.5, s, total) for f, s in notes]
    sparkle = np.zeros(int(SR * total))
    for _ in range(60):
        p = rng.integers(int(SR * 0.2), int(SR * (total - 0.2)))
        tl = 0.04; f = rng.uniform(5000, 10000)
        sparkle[p:p + int(SR * tl)] += osc(f, tl) * env(tl, 0.0005, 0.035) * rng.uniform(0.05, 0.2)
    sparkle *= np.linspace(1, 0.2, len(sparkle))
    low = osc(196, total) * env(total, 0.01, 1.8, curve=2) * 0.3   # warm root under it
    return finish(reverb(mix(*parts, sparkle, low), 1.4, 0.35, 8000))

# ---------- group 1: interface ----------
def ui_hover():
    d = 0.04
    tick = hp(noise(d), 5000) * env(d, 0.0002, 0.004) * 0.5
    blip = osc(2600, d) * env(d, 0.0003, 0.015) * 0.35
    return finish(reverb(mix(tick, blip), 0.1, 0.08), -9)          # deliberately quiet

def ui_open():
    d = 0.32
    slide = bandpass_sweep(noise(d), 700, 1800, q=1.5) * env(d, 0.04, 0.24, curve=1.5)
    grit = crackle(d, 90, 0.002) * env(d, 0.04, 0.22) * 0.25          # stone grain
    knock = (osc(sweep(140, 90, 0.2), 0.2) + 0.5 * lp(noise(0.2), 600)) * env(0.2, 0.001, 0.12)
    return finish(reverb(mix(slide, grit, at(knock, 0.22, d + 0.2)), 0.35, 0.2), -4)

def ui_error():
    total = 0.36
    def buzz(dur=0.11):
        b = osc(110, dur, "square") * 0.6 + osc(116, dur, "saw") * 0.4
        return lp(b, 1200) * env(dur, 0.003, 0.09, s=0.3, r=0.02)
    return finish(reverb(mix(at(buzz(), 0, total), at(buzz(), 0.16, total)), 0.2, 0.12), -4)

def menu_start():
    d = 2.6
    t = t_axis(d)
    partials = [(1.0, 1.0), (2.01, 0.5), (2.76, 0.35), (4.07, 0.2), (5.43, 0.12)]
    gong = sum(a * np.sin(2 * np.pi * 98 * r * t * (1 + 0.003 * np.sin(2 * np.pi * 3 * t)))
               * np.exp(-t * (1.2 + r * 0.6)) for r, a in partials)
    strike = lp(noise(d), 1500) * env(d, 0.001, 0.06) * 0.8
    shimmer = sum(osc(sweep(f, f * 1.5, d), d) for f in (1568, 2093, 2637)) / 3
    shimmer *= env(d, 0.6, 1.6, curve=1.2) * 0.18 * (0.7 + 0.3 * osc(7, d))
    return finish(reverb(mix(gong, strike, shimmer), 1.5, 0.35, 5000))

# ---------- group 2: player and combat ----------
def metal_ring(f0, dur, decay=6.0):
    t = t_axis(dur)
    parts = [(1.0, 1.0), (2.32, 0.6), (3.17, 0.4), (4.61, 0.25), (6.03, 0.15)]
    x = sum(a * np.sin(2 * np.pi * f0 * r * t) * np.exp(-t * decay * (0.7 + r * 0.3))
            for r, a in parts)
    return x * taper(len(x))

def impact(weight=1.0, d=0.5):
    """the punchy core every heavy hit shares: sub kick + crunchy body + crack."""
    kick = osc(sweep(220 * weight, 45, 0.18), 0.18) * env(0.18, 0.0005, 0.16, curve=2.5) * 1.4
    body = bandpass_sweep(noise(0.16), 1400, 300, q=1.2) * env(0.16, 0.0005, 0.12, curve=2.5) * 1.1
    crack = hp(noise(0.03), 3000) * env(0.03, 0.0002, 0.02) * 0.9
    return mix(kick, body, crack)

def sword_hit(v=0):
    p = [1.0, 0.92, 1.08][v]; d = 0.55
    shing = metal_ring(1150 * p, d, 15) * 0.35 + hp(noise(d), 4000) * env(d, 0.0005, 0.04) * 0.5
    x = mix(impact(p), shing)
    x = np.tanh(x * 2.2)                                   # drive it for weight
    return finish(reverb(x, 0.45, 0.2, 3500))

def sword_miss(v=0):
    d = 0.32; p = [1.0, 1.15][v]
    t = np.linspace(0, 1, int(SR * d))
    w = bandpass_sweep(noise(d), 600 * p, 4000 * p, q=2.0)
    w *= np.exp(-((t - 0.45) / 0.18) ** 2)                 # swells past the ear, doppler-like
    air = lp(noise(d), 500) * np.exp(-((t - 0.45) / 0.2) ** 2) * 0.6
    return finish(reverb(np.tanh(mix(w, air) * 2.5), 0.3, 0.15), -1)

def bow_shot():
    d = 0.7
    twang = (osc(sweep(220, 180, 0.3), 0.3, "tri") + 0.3 * osc(440, 0.3)) * env(0.3, 0.001, 0.25, curve=4)
    snap = hp(noise(0.03), 2000) * env(0.03, 0.0005, 0.02)
    whistle = bandpass_sweep(noise(0.5), 3000, 1800, q=8) * env(0.5, 0.05, 0.4, curve=1.5) * 0.8
    return finish(reverb(mix(twang, snap, at(whistle, 0.04, d)), 0.4, 0.18))

def crit():
    total = 2.2
    # 1) a quick reverse swell sucks in before the blow
    pre = 0.16
    suck = bandpass_sweep(noise(pre), 1000, 6000, q=1.5) * np.linspace(0, 1, int(SR * pre)) ** 3
    # 2) a huge impact: double kick, crunch, metal
    hit = mix(impact(1.0), at(impact(0.7) * 0.7, 0.025, 0.4))
    sub = osc(sweep(90, 30, 0.6), 0.6) * env(0.6, 0.001, 0.5, curve=2) * 1.3
    ring = metal_ring(1320, 0.6, 9) * 0.35
    blow = np.tanh(mix(hit, sub, ring) * 2.6)
    # 3) the satisfying part: a bright rising glint chord that rings out
    glint = sum(at(bell(f, 1.3) * 0.32, 0.06 + k * 0.045, 1.6) for k, f in enumerate((1318.5, 1760.0, 2217.5, 2637.0)))
    sparkle = hp(noise(1.6), 8000) * env(1.6, 0.05, 1.2, curve=2) * 0.12
    x = mix(at(suck, 0, total), at(blow, pre, total), at(mix(glint, sparkle), pre, total))
    return finish(reverb(x, 1.2, 0.28, 5000))

def sneak_attack():
    d = 0.9
    shk = bandpass_sweep(noise(0.14), 6000, 2500, q=3) * env(0.14, 0.002, 0.1)
    stab = metal_ring(2400, 0.2, 18) * 0.25
    low = (osc(73.4, d, "saw") * 0.5 + osc(77.8, d, "saw") * 0.5)          # D2 + Eb2 rub
    low = lp(low, 500) * env(d, 0.02, 0.8, curve=2) * 0.7
    return finish(reverb(mix(shk, stab, low), 0.6, 0.25))

def hide():
    d = 0.7
    swish = bandpass_sweep(noise(d), 2200, 400, q=1.2) * env(d, 0.08, 0.55, curve=1.5)
    tone = osc(sweep(330, 165, d), d) * env(d, 0.05, 0.6, curve=2) * 0.15
    return finish(reverb(mix(swish, tone), 0.6, 0.3), -4)

def spotted():
    total = 0.9
    # shadow peels away: a reversed swell rising out of silence...
    sw = 0.45
    k = np.linspace(0, 1, int(SR * sw))
    peel = bandpass_sweep(noise(sw), 300, 2800, q=1.3) * k ** 2.5
    tone = (osc(sweep(140, 420, sw), sw, "saw") * 0.5 + osc(sweep(148, 445, sw), sw, "saw") * 0.5)
    tone = lp(tone, 1800) * k ** 3 * 0.5
    # ...then she is exposed: a low 'dun' hit
    dun = (osc(sweep(110, 55, 0.4), 0.4) + 0.6 * lp(noise(0.4), 600)) * env(0.4, 0.001, 0.3)
    return finish(reverb(mix(at(mix(peel, tone), 0, total), at(dun, sw, total)), 0.6, 0.28, 3000))

def player_hurt(v=0):
    d = 0.4; p = [1.0, 0.88][v]
    thud = (osc(sweep(200 * p, 60, d), d) + 0.7 * lp(noise(d), 700)) * env(d, 0.001, 0.2)
    grit = bandpass_sweep(noise(0.15), 1500, 500, q=2) * env(0.15, 0.001, 0.1) * 0.5
    return finish(reverb(mix(thud, grit), 0.3, 0.15))

def player_death():
    total = 3.2
    fall = (osc(sweep(120, 35, 0.6), 0.6) + lp(noise(0.6), 500)) * env(0.6, 0.001, 0.45)
    clatter = metal_ring(900, 0.5, 10) * 0.25
    notes = [392.0, 349.2, 311.1, 261.6]                              # G F Eb C, falling
    tones = [at(note(f, 0.9, 0.05) * 0.5, 0.45 + k * 0.42, total) for k, f in enumerate(notes)]
    drone = lp(osc(65.4, total, "saw"), 300) * env(total, 0.6, 2.5, curve=1.5) * 0.3
    return finish(reverb(mix(at(fall, 0, total), at(clatter, 0.05, total), drone, *tones), 1.6, 0.35, 4000))

def voice(dur, f0_start, f0_end, formants, breath=0.25):
    """tiny formant voice: buzzy glottal source -> vowel resonances."""
    f0 = sweep(f0_start, f0_end, dur) * (1 + 0.012 * osc(5.5, dur))       # slight vibrato
    src = osc(f0, dur, "saw") * 0.7 + lp(noise(dur), 4000) * breath
    out = np.zeros_like(src)
    for fc, q, g in formants:
        b, a = signal.iirpeak(fc, q, fs=SR)
        out += signal.lfilter(b, a, src) * g
    return out

def ahh(dur=0.9):
    """a satisfied 'aah': breathy voice through 'ah' vowel formants."""
    n = int(SR * dur); k = np.linspace(0, 1, n)
    f0 = 150 - 45 * k + 3 * np.sin(2 * np.pi * 5 * k * dur)       # falls, with a little vibrato
    src = osc(f0, dur, "saw") * 0.7 + noise(dur) * 0.35          # voice + breath
    out = np.zeros(n)
    for fc, q, g in ((780, 6, 1.0), (1150, 8, 0.6), (2500, 10, 0.25), (3400, 12, 0.12)):
        b, a = signal.iirpeak(fc, q, fs=SR); out += g * signal.lfilter(b, a, src)
    shape = np.minimum(1, k / 0.12) * (1 - k) ** 1.6                # swell in, sigh out
    return lp(out, 4500) * shape

def potion():
    total = 1.9
    pop = (osc(sweep(900, 400, 0.04), 0.04) + noise(0.04) * 0.5) * env(0.04, 0.0005, 0.035)
    glugs = []
    for k in range(3):
        g = osc(sweep(300 + k * 60, 650 + k * 80, 0.09), 0.09) * env(0.09, 0.005, 0.08)
        glugs.append(at(lp(g, 2000) * 0.7, 0.18 + k * 0.13, total))
    return finish(reverb(mix(at(pop, 0, total), *glugs, at(ahh(1.0) * 1.3, 0.72, total)), 0.6, 0.2, 5000))

def pickup():
    total = 0.35
    a = osc(1318.5, 0.07, "square") * env(0.07, 0.001, 0.06) * 0.5
    b = osc(1975.5, 0.2, "square") * env(0.2, 0.001, 0.18) * 0.5
    return finish(reverb(lp(mix(a, at(b, 0.06, total)), 6000), 0.25, 0.15), -3)

def pickup_rare():
    total = 1.0
    parts = [at(bell(f, 0.7) * 0.5, s, total) for f, s in ((880, 0), (1108.7, 0.08), (1318.5, 0.16))]
    return finish(reverb(mix(*parts), 0.8, 0.28, 7000))

def equip():
    total = 0.45
    leather = bandpass_sweep(noise(0.12), 900, 2000, q=1.5) * env(0.12, 0.01, 0.1)
    clink1 = metal_ring(2100, 0.25, 14) * 0.35
    clink2 = metal_ring(2650, 0.2, 16) * 0.25
    return finish(reverb(mix(leather, at(clink1, 0.08, total), at(clink2, 0.16, total)), 0.3, 0.15), -2)

def discard():
    d = 0.35
    thud = (osc(sweep(130, 70, d), d) + lp(noise(d), 400)) * env(d, 0.001, 0.15)
    scrape = bandpass_sweep(noise(0.12), 1200, 600, q=2) * env(0.12, 0.001, 0.08) * 0.4
    return finish(reverb(mix(thud, scrape), 0.35, 0.2), -3)

def soft_ding(f, dur):
    """pure, harmonic ding (no inharmonic partials, so no 'metal pipe')."""
    t = t_axis(dur)
    x = np.sin(2*np.pi*f*t) + 0.25*np.sin(2*np.pi*2*f*t)*np.exp(-t*6) + 0.08*np.sin(2*np.pi*3*f*t)*np.exp(-t*10)
    return x * np.exp(-t * 5) * env(dur, 0.006, dur) ** 0 * taper(len(t))

def stat_point():
    total = 0.7
    pluck = lambda f, dur: (osc(f, dur) + 0.25 * osc(2 * f, dur)) * env(dur, 0.003, dur * 0.9, curve=3)
    a = pluck(784.0, 0.35) * 0.6
    b = pluck(1174.7, 0.5) * 0.6
    x = mix(a, at(b, 0.07, total)) * taper(int(SR * total), 0.3)
    return finish(reverb(lp(x, 5000), 0.5, 0.22, 6000), -10, sat=False)        # soft and quiet

def rest():
    d = 2.4
    chord = sum(osc(f, d, "tri") * (1 + 0.003 * osc(4 + k, d)) for k, f in enumerate((261.6, 329.6, 392.0, 523.3)))
    chord = lp(chord, 2500) * env(d, 0.7, 1.6, curve=1.3) * 0.35
    air = lp(noise(d), 1200) * env(d, 0.8, 1.4) * 0.12
    return finish(reverb(mix(chord, air), 1.2, 0.3, 5000), -3)

# ---------- group 3: spells ----------
def shimmer(dur, lo=4000, hi=9000, count=30, level=0.2):
    x = np.zeros(int(SR * dur))
    for _ in range(count):
        p = rng.integers(0, max(1, int(SR * (dur - 0.06))))
        tl = 0.05
        x[p:p + int(SR * tl)] += osc(rng.uniform(lo, hi), tl) * env(tl, 0.0005, 0.04) * rng.uniform(0.3, 1) * level
    return x

def spell_cast():
    d = 0.8
    swell = bandpass_sweep(noise(d), 400, 2500, q=2) * env(d, 0.25, 0.5, curve=1.5)
    tone = sum(osc(sweep(f, f * 1.5, d), d) for f in (440, 554, 659)) / 3 * env(d, 0.2, 0.55, curve=2) * 0.35
    return finish(reverb(mix(swell, tone, shimmer(d, level=0.15)), 0.7, 0.3, 7000))

def magic_missile():
    total = 1.0
    def dart(p):
        d = 0.22
        z = osc(sweep(500 * p, 2400 * p, d), d, "square") * 0.4 + osc(sweep(503 * p, 2410 * p, d), d, "saw") * 0.3
        return lp(z, 6000) * env(d, 0.002, 0.2, curve=2.5)
    parts = [at(dart(p), k * 0.17, total) for k, p in enumerate((1.0, 1.12, 1.26))]
    glow = sum(osc(f, total) for f in (740, 880)) / 2 * env(total, 0.05, 0.8, curve=2) * 0.12 * (0.6 + 0.4 * osc(9, total))
    return finish(reverb(mix(*parts, glow, shimmer(total, level=0.1)), 0.7, 0.3, 7000))

def scorching_ray():
    total = 1.1
    def ray():
        d = 0.28
        sz = bandpass_sweep(noise(d), 6000, 2500, q=2.5) * env(d, 0.005, 0.25, curve=1.5)
        hum = osc(sweep(700, 350, d), d, "saw") * env(d, 0.005, 0.22) * 0.25
        return mix(sz, lp(hum, 3000), crackle(d, 90) * 0.3)
    parts = [at(ray(), k * 0.27, total) for k in range(3)]
    return finish(reverb(mix(*parts), 0.5, 0.22))

def misty_step():
    total = 1.0
    out_ = bandpass_sweep(noise(0.3), 1200, 6000, q=2) * env(0.3, 0.01, 0.28, curve=1.5)
    vanish = osc(sweep(600, 2400, 0.3), 0.3) * env(0.3, 0.005, 0.28, curve=2) * 0.3
    k = np.linspace(0, 1, int(SR * 0.25))
    back = bandpass_sweep(noise(0.25), 5000, 1500, q=2) * k ** 2 * 0.6           # mist gathers
    pop = (osc(sweep(500, 200, 0.06), 0.06) + noise(0.06) * 0.4) * env(0.06, 0.0005, 0.05)
    return finish(reverb(mix(at(mix(out_, vanish), 0, total), at(back, 0.4, total), at(pop, 0.65, total)), 0.7, 0.3, 6000))

def sleep():
    total = 2.4
    notes = [(1174.7, 0.0), (987.8, 0.35), (880.0, 0.7), (739.99, 1.05)]       # D C# A F# down
    parts = [at(bell(f, 1.2) * 0.4, s, total) for f, s in notes]
    hum = lp(osc(146.8, total, "tri") + osc(147.5, total, "tri"), 600) * env(total, 0.5, 1.8, curve=1.3) * 0.3
    air = lp(noise(total), 900) * env(total, 0.6, 1.6) * 0.08
    return finish(reverb(mix(*parts, hum, air) * 0.7, 1.6, 0.4, 4000), -11, sat=False)

def hold():
    total = 1.3
    d = 0.7
    rise = (osc(sweep(150, 600, d), d, "saw") * 0.5 + osc(sweep(158, 632, d), d, "saw") * 0.5)
    rise = lp(rise, 2500) * env(d, 0.3, 0.4, s=0.5, r=0.05) * 0.6
    clank = mix(impact(0.8) * 0.6, metal_ring(700, 0.5, 8) * 0.5, at(metal_ring(830, 0.4, 10) * 0.35, 0.06, 0.5))
    lock = osc(600, 0.6, "saw") * env(0.6, 0.001, 0.5, s=0.0, curve=1.5) * 0.15
    return finish(reverb(mix(at(rise, 0, total), at(np.tanh(clank * 2), d, total), at(lp(lock, 2000), d, total)), 0.7, 0.28))

def haste():
    total = 1.0
    whoosh = bandpass_sweep(noise(total), 300, 5000, q=1.8) * env(total, 0.5, 0.45, curve=1.5)
    ticks = np.zeros(int(SR * total)); tpos = 0.0; gap = 0.12
    while tpos < 0.85:                                        # clock ticks that speed up
        tl = 0.012; p = int(SR * tpos)
        ticks[p:p + int(SR * tl)] += hp(noise(tl), 3000) * env(tl, 0.0002, 0.01) * 0.6
        tpos += gap; gap = max(gap * 0.8, 0.03)
    tone = osc(sweep(330, 1320, total), total, "tri") * env(total, 0.4, 0.55, curve=2) * 0.25
    return finish(reverb(mix(whoosh, ticks, tone), 0.5, 0.22))

def formant_voice(f0, dur, formants, breath=0.3):
    src = osc(f0, dur, "saw") * 0.7 + noise(dur) * breath
    out = np.zeros_like(src)
    for fc, q, g in formants:
        b, a = signal.iirpeak(fc, q, fs=SR); out += g * signal.lfilter(b, a, src)
    return out

def vampiric_touch():
    total = 2.6
    d = 1.2; k = np.linspace(0, 1, int(SR * d))
    # 1) the soul: a ghostly 'ooo' wail dragged downward out of the target
    f0 = 520 * (0.35 ** k) * (1 + 0.03 * np.sin(2 * np.pi * 6 * k * d))
    wail = formant_voice(f0, d, ((350, 8, 1.0), (800, 10, 0.5), (2400, 12, 0.15)), 0.2)
    wail2 = formant_voice(f0 * 1.5, d, ((350, 8, 1.0), (800, 10, 0.5)), 0.1) * 0.4
    ghost = lp(mix(wail, wail2), 3500) * k ** 0.6 * (1 - k) ** 0.8 * 3.0
    vac = bandpass_sweep(noise(d), 4000, 250, q=1.4) * k ** 2 * 0.9
    # 2) the drain lands: a low gulp
    gulp = osc(sweep(140, 40, 0.4), 0.4) * env(0.4, 0.002, 0.35, curve=2) * 1.2
    # 3) the lifesteal: stolen life flows INTO you - rising warm whoosh, rich chord, heartbeat
    h = 1.2
    up = bandpass_sweep(noise(h), 300, 3000, q=1.5) * env(h, 0.25, 0.9, curve=1.5) * 0.6
    chord = sum(osc(sweep(f * 0.75, f, h), h, "saw") * (1 + 0.004 * osc(5 + j, h)) for j, f in enumerate((293.7, 349.2, 440.0, 587.3)))
    chord = lp(chord, 2200) * env(h, 0.15, 1.0, curve=1.5) * 0.3
    beat = lambda: osc(sweep(90, 50, 0.16), 0.16) * env(0.16, 0.001, 0.14, curve=2)
    hb = mix(*[at(beat() * g, t0, h) for t0, g in ((0.1, 0.8), (0.3, 0.6), (0.65, 1.0), (0.85, 0.75))])
    gain = mix(up, chord, hb, shimmer(h, 3000, 7000, 20, 0.12))
    x = mix(at(mix(ghost, vac), 0, total), at(gulp, d - 0.05, total), at(gain, d + 0.05, total))
    return finish(reverb(x, 1.1, 0.3, 3500))

def sunbeam():
    total = 1.8
    d = 1.0
    # the boom: sunlight slams into the target
    boom = mix(osc(sweep(120, 30, 1.0), 1.0) * env(1.0, 0.001, 0.8, curve=2) * 1.6,
               lp(noise(0.8), 700) * env(0.8, 0.001, 0.6, curve=2.5) * 1.1,
               hp(noise(0.05), 2500) * env(0.05, 0.0002, 0.04) * 1.2)
    # the focused beam: a bright, tight, searing chord with an energy flutter
    beam = sum(osc(f * (1 + 0.002 * osc(23 + j, d)), d, "saw") for j, f in enumerate((523.3, 784.0, 1046.5, 1568.0)))
    beam = bandpass_sweep(beam, 2200, 1600, q=1.2) * env(d, 0.002, 0.35, s=0.6, r=0.35) * 0.45
    beam *= 1 + 0.25 * osc(31, d)
    sear = bandpass_sweep(noise(d), 7000, 4000, q=3) * env(d, 0.002, 0.4, s=0.45, r=0.3) * 0.6
    core = lp(osc(130.8, d, "saw"), 600) * env(d, 0.002, 0.5, s=0.5, r=0.3) * 0.6
    x = mix(np.tanh(boom * 1.8), beam, sear, core, shimmer(d, 6000, 11000, 25, 0.12))
    x = np.tanh(x * 1.0)                                       # a little denser = louder
    return finish(reverb(x, 0.7, 0.2, 5000), -5.5)

def ice_storm():
    total = 2.2
    wind = bandpass_sweep(noise(total), 300, 1200, q=1.0) * env(total, 0.3, 1.7, curve=1.3) * 0.8
    wind *= 0.7 + 0.3 * lp(noise(total), 3) * 40
    hail = np.zeros(int(SR * total))
    for _ in range(140):
        p = rng.integers(int(SR * 0.25), int(SR * (total - 0.3)))
        tl = 0.02
        hail[p:p + int(SR * tl)] += hp(noise(tl), 2500) * env(tl, 0.0003, 0.015) * rng.uniform(0.2, 0.8)
    cracks = mix(*[at(mix(np.tanh(impact(0.9) * 1.5) * 0.6, metal_ring(rng.uniform(2500, 3500), 0.2, 20) * 0.3), s, total)
                   for s in (0.35, 0.8, 1.3)])
    return finish(reverb(mix(wind, hail * 0.9, cracks), 1.0, 0.3, 5000))

def smooth_rand(dur, rate):
    """slowly wandering random curve in 0..1 (cubic-interpolated control points)."""
    n = int(SR * dur); pts = rng.uniform(0, 1, int(dur * rate) + 4)
    xs = np.linspace(0, len(pts) - 1, n)
    from scipy.interpolate import CubicSpline
    return np.clip(CubicSpline(np.arange(len(pts)), pts)(xs), 0, 1)

def moving_lp(x, cutoff_curve, blocks=200):
    """low-pass whose cutoff follows a curve, smoothly (one-pole, per-sample coefficient)."""
    c = np.exp(-2 * np.pi * cutoff_curve / SR)
    y = np.zeros_like(x); acc = 0.0
    # vectorised-ish one-pole in chunks
    for i in range(0, len(x), 512):
        seg = x[i:i + 512]; cc = c[i:i + 512]
        out = np.empty_like(seg)
        for j in range(len(seg)):
            acc = cc[j] * acc + (1 - cc[j]) * seg[j]; out[j] = acc
        y[i:i + 512] = out
    return y

def cone_of_cold():
    total = 1.6
    d = 1.3
    # wind body: brown noise through a cutoff that wanders like real gusts
    brown = np.cumsum(noise(d)); brown = hp(brown - np.mean(brown), 40); brown /= np.max(np.abs(brown))
    gusts = smooth_rand(d, 9)
    wind = moving_lp(mix(brown * 0.8, noise(d) * 0.35), 300 + 2200 * gusts)
    wind = moving_lp(wind, 300 + 2200 * gusts)                 # 2nd pass = smoother slope
    wind *= (0.55 + 0.45 * gusts) * env(d, 0.03, 1.15, curve=1.4) * 2.2
    # driving snow: grainy, not a steady hiss
    grains = np.zeros(int(SR * d))
    for _ in range(900):
        p = rng.integers(0, int(SR * (d - 0.02))); tl = rng.uniform(0.002, 0.008)
        grains[p:p + int(SR * tl)] += noise(tl) * np.hanning(int(SR * tl)) * rng.uniform(0.05, 0.4)
    snow = hp(grains, 2500) * (0.4 + 0.6 * gusts) * env(d, 0.02, 1.1, curve=1.6) * 0.8
    # frost cracking on the floor where it lands
    cracks = np.zeros(int(SR * d))
    for _ in range(14):
        p = rng.integers(int(SR * 0.15), int(SR * (d - 0.15))); tl = 0.03
        cracks[p:p + int(SR * tl)] += hp(noise(tl), 1500) * env(tl, 0.0003, 0.02) * rng.uniform(0.2, 0.6)
    blast = lp(noise(0.3), 350) * env(0.3, 0.002, 0.25) * 0.9
    return finish(reverb(mix(wind, snow, cracks * 0.7, blast), 0.9, 0.3, 6000))

# ---------- group 4: puzzles and world ----------
def torch_off():
    d = 0.7
    snuff = bandpass_sweep(noise(0.25), 2500, 600, q=1.2) * env(0.25, 0.005, 0.22, curve=1.5)
    thump = lp(noise(0.1), 300) * env(0.1, 0.001, 0.08) * 0.6
    smoke = hp(noise(d), 4000) * env(d, 0.12, 0.5, curve=1.3) * 0.18
    return finish(reverb(mix(snuff, thump, smoke), 0.4, 0.2), -3)

def wire_power():
    total = 0.9
    crackle_on = crackle(0.12, 300, 0.003) * 1.2
    rise = np.concatenate([sweep(60, 120, 0.25), np.full(int(SR * total) - int(SR * 0.25), 120.0)])
    hum = osc(rise, total, "saw") * 0.5 + osc(rise * 2, total, "square") * 0.2
    hum = lp(hum, 2500) * env(total, 0.02, 0.6, s=0.25, r=0.2)
    buzz = bandpass_sweep(noise(total), 1500, 3500, q=4) * env(total, 0.05, 0.5, s=0.1, r=0.2) * 0.3
    return finish(reverb(mix(crackle_on, hum, buzz), 0.4, 0.2), -3)

def gate_rotate():
    total = 0.75
    d = 0.5
    grind = bandpass_sweep(noise(d), 400, 900, q=1.5) * env(d, 0.05, 0.4, s=0.4, r=0.1)
    grind *= 0.7 + 0.3 * np.sign(osc(28, d))                   # stuttering stone friction
    grit = crackle(d, 120, 0.002) * env(d, 0.05, 0.45) * 0.3
    click = mix(impact(1.3) * 0.5, metal_ring(1900, 0.15, 25) * 0.3)
    return finish(reverb(mix(at(mix(grind, grit), 0, total), at(np.tanh(click * 2), d - 0.04, total)), 0.4, 0.2))

def door_open():
    total = 3.0
    d = 1.9
    rumble = lp(noise(d), 180) * env(d, 0.25, 1.4, s=0.6, r=0.25) * 1.2
    grind = bandpass_sweep(noise(d), 250, 600, q=1.3) * env(d, 0.3, 1.4, s=0.5, r=0.2) * 0.7
    grind *= 0.75 + 0.25 * np.sign(osc(18, d))
    grit = crackle(d, 70, 0.003) * env(d, 0.3, 1.5) * 0.25
    thud = mix(osc(sweep(90, 35, 0.6), 0.6) * env(0.6, 0.001, 0.5, curve=2) * 1.4,
               lp(noise(0.4), 500) * env(0.4, 0.001, 0.3) * 0.8)
    chime = mix(*[at(bell(f, 1.0) * 0.3, k * 0.09, 1.2) for k, f in enumerate((659.3, 880.0, 1318.5))])
    x = mix(at(mix(rumble, grind, grit), 0, total), at(thud, d - 0.1, total), at(chime, d + 0.05, total))
    return finish(reverb(x, 1.1, 0.3, 3500))

def door_locked():
    total = 0.7
    def clunk(w):
        return mix(impact(w) * 0.7, metal_ring(520 * w, 0.2, 18) * 0.35)
    rattle = mix(*[at(clunk(rng.uniform(0.7, 0.9)) * rng.uniform(0.4, 0.7), s, 0.5) for s in (0, 0.05, 0.1, 0.14)])
    big = clunk(0.6)
    return finish(reverb(np.tanh(mix(at(rattle, 0, total), at(big, 0.24, total)) * 1.5), 0.4, 0.2), -2)

def plaque_read():
    d = 1.1
    rustle = np.zeros(int(SR * d))
    for s0 in (0.0, 0.18, 0.33):
        rl = 0.22
        r = bandpass_sweep(noise(rl), 2500, 5000, q=1.5) * env(rl, 0.02, 0.18)
        r *= 0.6 + 0.4 * np.abs(np.clip(lp(noise(rl), 40) * 20, -1, 1))
        rustle[int(SR * s0):int(SR * s0) + len(r)] += r * 0.6
    dust = hp(noise(d), 6000) * env(d, 0.1, 0.8) * 0.08
    tone = (osc(196, d) + 0.5 * osc(293.7, d)) * env(d, 0.15, 0.9, curve=1.5) * 0.18
    return finish(reverb(mix(rustle, dust, tone), 0.8, 0.3, 5000), -4)

def stairs():
    total = 2.2
    def step(k):
        d = 0.25
        st = mix(osc(sweep(140, 70, 0.12), 0.12) * env(0.12, 0.001, 0.1) * 0.8,
                 bandpass_sweep(noise(d), 1800, 700, q=1.2) * env(d, 0.001, 0.08) * 0.6)
        return reverb(st, 0.3 + 0.25 * k, 0.15 + 0.12 * k, 3000) * (1 - 0.12 * k)
    parts = [at(step(k), 0.38 * k, total) for k in range(4)]
    return finish(mix(*parts), -2)

# ---------- group 5: enemies ----------
VOWELS = {   # formant (Hz, Q, gain) sets
    "ee": ((300, 8, 1.0), (2300, 10, 0.7), (3000, 12, 0.4)),
    "eh": ((550, 7, 1.0), (1800, 9, 0.6), (2500, 11, 0.3)),
    "uh": ((620, 6, 1.0), (1150, 8, 0.6), (2400, 10, 0.2)),
    "oh": ((450, 7, 1.0), (800, 8, 0.6), (2500, 12, 0.15)),
    "ah": ((780, 6, 1.0), (1150, 8, 0.6), (2500, 10, 0.25)),
}

def creature(f0_curve, dur, v1, v2=None, growl=0.0, breath=0.25, nasal=False, throat=1.0):
    """retro creature voice: pitch curve, vowel morph v1->v2, optional growl roughness."""
    n = int(SR * dur); k = np.linspace(0, 1, n)
    f0 = np.broadcast_to(f0_curve, n).astype(float)
    if growl:   # roughness: fast random pitch + amplitude jitter
        f0 = f0 * (1 + growl * 0.08 * np.clip(lp(noise(dur), 60) * 30, -1, 1))
    src = osc(f0, dur, "saw") * 0.8 + noise(dur) * breath
    if growl:
        src *= 1 + growl * 0.6 * osc(f0 * 0.5, dur, "square")
    def vowel(v):
        out = np.zeros(n)
        for fc, q, g in VOWELS[v]:
            b, a = signal.iirpeak(fc * throat, q, fs=SR); out += g * signal.lfilter(b, a, src)
        return out
    out = vowel(v1) if not v2 else vowel(v1) * (1 - k) + vowel(v2) * k
    if nasal:
        b, a = signal.iirpeak(1000, 3, fs=SR); out += 0.4 * signal.lfilter(b, a, out)
        b, a = signal.iirnotch(500, 2, fs=SR); out = signal.lfilter(b, a, out)
    return lp(out, 5000)

def bone_clack(pitch=1.0, level=1.0):
    d = 0.06
    c = bandpass_sweep(noise(d), 2500 * pitch, 1800 * pitch, q=4, blocks=8) * env(d, 0.0003, 0.03, curve=4)
    tone = osc(rng.uniform(900, 1400) * pitch, d) * env(d, 0.0003, 0.025) * 0.4
    return (c + tone) * level

def body_drop(weight=1.0, d=0.5):
    return mix(osc(sweep(110 * weight, 40, d), d) * env(d, 0.001, 0.3, curve=2) * 1.1,
               lp(noise(d), 500) * env(d, 0.001, 0.2) * 0.7)

def goblin_hit():
    total = 0.5; d = 0.28; k = np.linspace(0, 1, int(SR * d))
    v = creature(620 * (1 + 0.5 * np.sin(np.pi * k)), d, "ee", "eh", growl=0.3, nasal=True)
    v *= env(d, 0.01, 0.25, curve=1.5)
    return finish(reverb(mix(at(impact(1.2) * 0.6, 0, total), at(v * 1.2, 0.02, total)), 0.4, 0.2))

def goblin_death():
    total = 1.3; d = 0.75; k = np.linspace(0, 1, int(SR * d))
    v = creature(700 * (0.45 ** k) * (1 + 0.04 * np.sin(2 * np.pi * 9 * k)), d, "ee", "uh", growl=0.4, nasal=True)
    v *= env(d, 0.01, 0.7, curve=1.2)
    return finish(reverb(mix(at(v, 0, total), at(body_drop(1.3, 0.4) * 0.7, d - 0.05, total)), 0.6, 0.25))

def skeleton_hit():
    total = 0.45
    parts = [at(bone_clack(rng.uniform(0.9, 1.2), g), t0, total)
             for t0, g in ((0, 1.0), (0.04, 0.6), (0.07, 0.5), (0.1, 0.35), (0.15, 0.25), (0.19, 0.15))]
    return finish(reverb(mix(at(impact(1.4) * 0.35, 0, total), *parts), 0.4, 0.22))

def skeleton_death():
    total = 1.8
    parts = []; t0 = 0.0; gap = 0.03
    for j in range(26):                                        # cascade that slows and settles
        parts.append(at(bone_clack(rng.uniform(0.6, 1.3), rng.uniform(0.3, 1.0) * (1 - j / 32)), t0, total))
        t0 += gap * rng.uniform(0.6, 1.6); gap *= 1.07
    skull = at(mix(bone_clack(0.55, 1.0), osc(sweep(300, 180, 0.2), 0.2) * env(0.2, 0.001, 0.15) * 0.4), t0 + 0.05, total)
    return finish(reverb(mix(at(impact(1.0) * 0.5, 0, total), *parts, skull), 0.7, 0.28))

def monster(f0_curve, dur, v1, v2=None, throat=0.72, size=1.0):
    """big-creature voice: low voice + growl an octave down + vocal-fry rasp + drive."""
    n = int(SR * dur)
    f0 = np.broadcast_to(f0_curve, n).astype(float)
    main = creature(f0, dur, v1, v2, growl=1.3, breath=0.35, throat=throat)
    sub = creature(f0 * 0.5, dur, v1, v2, growl=1.6, breath=0.2, throat=throat * 0.85) * 0.9
    fry = noise(dur) * (0.5 + 0.5 * osc(f0 * 0.25, dur, "square"))            # rattling throat
    fry = bandpass_sweep(fry, 700 * throat, 500 * throat, q=1.5, blocks=16) * 0.5
    x = mix(main, sub, fry) * size
    return lp(np.tanh(x * 3.0), 3800)

def orc_hit():
    total = 0.6; d = 0.38; k = np.linspace(0, 1, int(SR * d))
    v = monster(85 * (1 + 0.3 * np.sin(np.pi * k)), d, "uh", "ah") * env(d, 0.01, 0.35, curve=1.3)
    return finish(reverb(np.tanh(mix(at(impact(0.8) * 0.8, 0, total), at(v * 1.3, 0.015, total)) * 1.4), 0.5, 0.22, 3000))

def orc_death():
    total = 2.4; d = 1.6; k = np.linspace(0, 1, int(SR * d))
    v = monster(100 * (0.45 ** k) * (1 + 0.04 * np.sin(2 * np.pi * 4 * k)), d, "ah", "oh") * env(d, 0.04, 1.5, curve=1.0)
    return finish(reverb(np.tanh(mix(at(v * 1.3, 0, total), at(body_drop(0.8, 0.7) * 1.2, d - 0.1, total)) * 1.3), 0.9, 0.3, 3000), -4)

def enemy_hit():
    total = 0.4
    return finish(reverb(np.tanh(impact(1.0) * 2.0), 0.35, 0.18))

def enemy_death():
    total = 1.4
    dark = lp(osc(sweep(110, 55, 1.0), 1.0, "saw") + osc(sweep(116, 58, 1.0), 1.0, "saw"), 500) * env(1.0, 0.01, 0.95, curve=1.5) * 0.35
    return finish(reverb(mix(at(np.tanh(impact(0.9) * 1.8), 0, total), at(body_drop(1.0) * 0.8, 0.05, total), at(dark, 0.08, total)), 0.8, 0.28))

# ---------- group 6: bosses ----------
def brass(freqs, dur, bright=1800):
    """dark brass-like swell: detuned saws, filter opens as it swells."""
    x = sum(osc(f * (1 + dt), dur, "saw") for f in freqs for dt in (-0.003, 0.0, 0.004)) / (3 * len(freqs))
    k = np.linspace(0, 1, int(SR * dur))
    return moving_lp(x, 200 + bright * np.minimum(1, k * 2.5) * (1 - k * 0.5))

def thunder(dur=2.0):
    rumble = moving_lp(np.cumsum(noise(dur)), 120 + 400 * smooth_rand(dur, 6))
    rumble = hp(rumble - np.mean(rumble), 30); rumble /= np.max(np.abs(rumble))
    return rumble * (0.4 + 0.6 * smooth_rand(dur, 5)) * env(dur, 0.05, dur * 0.95, curve=1.4)

def glass_shatter(dur=1.4, n=90, lo=2500, hi=9000):
    x = np.zeros(int(SR * dur))
    crash = hp(noise(0.12), 2000) * env(0.12, 0.0003, 0.1, curve=2.5) * 1.2
    x[:len(crash)] += crash
    for j in range(n):                                        # shards falling and tinkling
        p = int(SR * min(dur - 0.15, abs(rng.normal(0.05, 0.35))))
        tl = 0.12
        x[p:p + int(SR * tl)] += (bell(rng.uniform(lo, hi), tl) * rng.uniform(0.1, 0.45))[:len(x) - p]
    return x

def electric(dur, density=400):
    return mix(crackle(dur, density, 0.002) * 1.2,
               bandpass_sweep(noise(dur), 2500, 5000, q=3) * 0.4) * (0.5 + 0.5 * np.abs(np.sign(osc(37, dur, "square"))))

def boss_intro():
    total = 3.6
    hit = np.tanh(mix(impact(0.6) * 1.2, osc(sweep(70, 28, 2.0), 2.0) * env(2.0, 0.001, 1.8, curve=1.8) * 1.6) * 1.8)
    swell = brass((55.0, 82.4, 110.0, 130.8), 3.0, 1600) * env(3.0, 0.4, 2.4, curve=1.4) * 1.4
    return finish(reverb(mix(hit, at(swell, 0.1, total)), 1.8, 0.35, 3000))

def boss_death():
    total = 5.0
    rum = thunder(2.4) * 1.0
    cracks = mix(*[at(np.tanh(impact(rng.uniform(0.6, 1.0)) * 1.5) * rng.uniform(0.3, 0.6), t0, 2.4)
                   for t0 in (0.2, 0.55, 0.9, 1.3, 1.6)])
    final = np.tanh(mix(impact(0.5) * 1.3, osc(sweep(80, 25, 1.6), 1.6) * env(1.6, 0.001, 1.4, curve=2) * 1.8) * 2)
    shimmer_up = sum(osc(sweep(f, f * 2, 2.4), 2.4) for f in (523.3, 659.3, 784.0)) / 3 * env(2.4, 0.8, 1.5, curve=1.5) * 0.25
    x = mix(rum, cracks, at(final, 2.0, total), at(mix(shimmer_up, shimmer(2.4, 4000, 9000, 40, 0.12)), 2.4, total))
    return finish(reverb(x, 2.0, 0.35, 4000))

def warden_shield_break():
    total = 2.0
    over = 0.6; k = np.linspace(0, 1, int(SR * over))
    hum = osc(sweep(120, 480, over), over, "saw") * 0.5 + electric(over) * k
    hum = lp(hum, 5000) * k ** 1.5
    burst = mix(glass_shatter(1.3, 70), electric(0.3) * env(0.3, 0.001, 0.28) * 1.2, np.tanh(impact(0.9) * 1.5))
    return finish(reverb(mix(at(hum, 0, total), at(burst, over, total)), 1.0, 0.3, 6000))

def warden_teleport():
    total = 1.1
    zap_out = mix(electric(0.25), osc(sweep(300, 2500, 0.25), 0.25, "saw") * 0.4) * env(0.25, 0.002, 0.23)
    k = np.linspace(0, 1, int(SR * 0.2))
    zap_in = mix(electric(0.2), osc(sweep(2500, 300, 0.2), 0.2, "saw") * 0.4) * k ** 2
    land = mix(np.tanh(impact(1.1) * 1.4) * 0.7, crackle(0.3, 200) * env(0.3, 0.001, 0.25))
    return finish(reverb(mix(at(lp(zap_out, 7000), 0, total), at(lp(zap_in, 7000), 0.5, total), at(land, 0.7, total)), 0.6, 0.25))

def shade_snuff():
    total = 2.6
    cold = bandpass_sweep(noise(0.7), 3000, 300, q=1.2) * env(0.7, 0.05, 0.6, curve=1.5)
    snuffs = mix(*[at(torch_off() * 0.35, t0, 1.0) for t0 in (0.15, 0.22, 0.3, 0.36)])
    whisper = mix(*[bandpass_sweep(noise(1.8), f, f * 0.8, q=6) for f in (900, 1400, 2300)])
    whisper *= (0.3 + 0.7 * smooth_rand(1.8, 7)) * env(1.8, 0.4, 1.3, curve=1.2) * 0.6
    hum = lp(osc(98, 1.8) + osc(103.8, 1.8), 400) * env(1.8, 0.5, 1.2) * 0.3
    return finish(reverb(mix(cold, snuffs, at(mix(whisper, hum), 0.6, total)), 1.6, 0.4, 3000))

def lantern_blaze():
    total = 2.0
    roar = mix(torch_on() * 1.0, lp(noise(1.2), 600) * env(1.2, 0.02, 1.0) * 0.8)
    holy = sum(osc(f, 1.4, "tri") for f in (523.3, 659.3, 784.0, 1046.5)) / 4 * env(1.4, 0.03, 1.3, curve=1.5) * 0.5
    recoil = creature(sweep(240, 150, 0.5), 0.5, "ah", "oh", growl=0.6, breath=0.5) * env(0.5, 0.02, 0.45) * 0.6
    return finish(reverb(mix(roar, at(mix(holy, shimmer(1.4, 4000, 9000, 35, 0.15)), 0.05, total), at(recoil, 0.25, total)), 1.1, 0.3, 6000))

def ymir_spell():
    total = 1.6
    charge = brass((110.0, 116.5), 0.4, 1200) * np.linspace(0, 1, int(SR * 0.4)) ** 2 * 0.8
    bolt = mix(bandpass_sweep(noise(0.6), 2500, 300, q=1.5) * env(0.6, 0.005, 0.5),
               osc(sweep(600, 80, 0.6), 0.6, "saw") * env(0.6, 0.005, 0.5) * 0.4,
               np.tanh(impact(0.7) * 1.6))
    return finish(reverb(mix(at(charge, 0, total), at(lp(bolt, 5000), 0.4, total), at(shimmer(0.8, 2000, 5000, 15, 0.15), 0.4, total)), 1.0, 0.3, 4000))

def ymir_wave():
    total = 2.2
    d = 1.6
    pulse = osc(sweep(60, 35, d), d) * env(d, 0.01, 1.4, curve=1.6) * 1.3
    wob = (osc(sweep(120, 70, d), d, "saw") + osc(sweep(123, 72, d), d, "saw")) * (0.6 + 0.4 * osc(sweep(8, 3, d), d))
    wob = moving_lp(wob * env(d, 0.01, 1.4, curve=1.5), 300 + 1500 * np.linspace(1, 0, int(SR * d)) ** 2) * 0.7
    rush = bandpass_sweep(noise(d), 400, 3000, q=1.2) * env(d, 0.1, 1.3, curve=1.6) * 0.8
    return finish(reverb(np.tanh(mix(pulse, wob, rush) * 1.4), 1.3, 0.3, 4000), -5)

def ymir_stun():
    d = 1.8; k = np.linspace(0, 1, int(SR * d))
    warble = osc(1100 * (1 + 0.12 * np.sin(2 * np.pi * 5 * k * d)), d) + 0.5 * osc(1650 * (1 + 0.12 * np.sin(2 * np.pi * 5 * k * d + 2)), d)
    warble *= env(d, 0.01, 1.7, curve=1.6) * 0.35 * (0.6 + 0.4 * np.sin(2 * np.pi * 2.5 * k * d))   # circling
    tinks = mix(*[at(bell(f, 0.4) * 0.11, t0, d) for t0, f in zip(np.arange(0.05, 1.5, 0.17), (2637, 3136, 3520, 3136) * 3)])
    hit = np.tanh(impact(1.0) * 1.3) * 0.6
    return finish(reverb(mix(hit, warble, tinks), 1.0, 0.3, 7000), -2)

def ward_shatter():
    total = 2.0
    crack = mix(np.tanh(impact(1.2) * 1.5), metal_ring(2900, 0.3, 10) * 0.4)
    return finish(reverb(mix(crack, glass_shatter(1.9, 120, 2000, 10000)), 1.2, 0.3, 8000))

def altair_lightning():
    total = 3.2
    # 1) the leader: a fast tearing sizzle as the bolt forms (0.18 s)
    pre = 0.18; k = np.linspace(0, 1, int(SR * pre))
    tear = hp(crackle(pre, 1500, 0.0015) * 1.0 + noise(pre) * 0.3, 2500) * k ** 2
    # 2) the strike: a massive full-band KRAK, ripping crackle, close thunder boom
    krak = noise(0.12) * env(0.12, 0.0001, 0.1, curve=3) * 2.0
    rip = hp(crackle(0.45, 900, 0.002), 1200) * env(0.45, 0.0005, 0.42, curve=2) * 1.4
    boom = np.tanh(mix(osc(sweep(90, 30, 1.2), 1.2) * env(1.2, 0.001, 1.0, curve=2) * 1.6,
                       lp(noise(1.0), 400) * env(1.0, 0.001, 0.8, curve=2) * 1.4) * 2)
    # 3) the roll: thunder rumbling away
    roll = np.tanh(thunder(2.6) * 2.5) * 1.2
    strike = mix(krak, rip, boom, at(roll, 0.25, 2.9))
    return finish(reverb(np.tanh(mix(at(tear, 0, total), at(strike, pre, total)) * 1.3), 1.6, 0.3, 5000), -2.5)

def smo_slam():
    total = 3.0
    sw = 0.35
    swing = bandpass_sweep(noise(sw), 250, 1000, q=1.5) * np.linspace(0, 1, int(SR * sw)) ** 2.5 * 0.7
    # the BOOM: an explosion-sized low end
    d = 2.2
    sub = osc(sweep(65, 18, d), d) * env(d, 0.001, 1.9, curve=1.7) * 2.2
    blast = lp(noise(d), 260) * env(d, 0.001, 1.6, curve=2.2) * 2.0
    body = lp(noise(0.4), 900) * env(0.4, 0.0005, 0.3, curve=2.5) * 1.5
    crack = hp(noise(0.04), 1500) * env(0.04, 0.0002, 0.03) * 1.2
    boom = np.tanh(mix(sub, blast, body, crack) * 2.6)
    rubble = moving_lp(noise(1.8), 300 + 500 * smooth_rand(1.8, 10)) * env(1.8, 0.05, 1.6, curve=1.5) * 0.6
    return finish(reverb(mix(at(swing, 0, total), at(boom, sw, total), at(rubble, sw + 0.1, total)), 1.4, 0.3, 2500), -4.5)

def bit_swap():
    total = 1.5
    d = 0.9; k = np.linspace(0, 1, int(SR * d))
    # two energy streams cross: one climbs, the other falls, and they trade places
    up = osc(110 * 4 ** k, d, "saw") * 0.5 + osc(111 * 4 ** k, d, "square") * 0.2
    down = osc(440 * 0.25 ** k, d, "saw") * 0.5 + osc(442 * 0.25 ** k, d, "square") * 0.2
    streams = lp(mix(up, down), 3500) * env(d, 0.05, 0.8, s=0.3, r=0.1) * 0.8
    # where they cross: a surge of crackling power and a rush of air
    cross = np.exp(-((k - 0.5) / 0.12) ** 2)
    surge = mix(electric(d) * cross * 1.2, bandpass_sweep(noise(d), 600, 4000, q=1.5) * cross * 0.8)
    # the new state locks in
    lock = mix(np.tanh(impact(1.0) * 1.5) * 0.7, electric(0.25) * env(0.25, 0.001, 0.22))
    return finish(reverb(mix(at(mix(streams, surge), 0, total), at(lock, d - 0.05, total)), 0.9, 0.28, 5000))

def duo_empower():
    total = 3.0
    d = 2.0; k = np.linspace(0, 1, int(SR * d))
    # a scream that climbs as the power floods in
    f0 = 140 + 200 * k ** 1.3 + 8 * np.sin(2 * np.pi * 7 * k * d) * k
    scream = mix(creature(f0, d, "ah", "ee", growl=1.0, breath=0.45, throat=0.9),
                 creature(f0 * 0.5, d, "ah", "eh", growl=1.5, breath=0.2, throat=0.75) * 0.7)
    scream = lp(np.tanh(scream * 3.0), 4500) * env(d, 0.15, 1.7, s=0.0, curve=0.8) * 1.2
    energy = electric(d) * k ** 1.5 * 0.8
    rise = brass((55.0, 82.4, 110.0), d, 2200) * k ** 2 * 0.7
    burst = np.tanh(mix(impact(0.6) * 1.2, osc(sweep(80, 30, 0.9), 0.9) * env(0.9, 0.001, 0.8) * 1.5,
                        electric(0.4) * env(0.4, 0.001, 0.35)) * 1.8)
    return finish(reverb(mix(at(mix(scream, energy, rise), 0, total), at(burst, d - 0.1, total)), 1.3, 0.3, 4000))

def throne_slam():
    total = 2.2
    slam = np.tanh(mix(impact(0.5) * 1.4, osc(sweep(60, 25, 1.2), 1.2) * env(1.2, 0.001, 1.0, curve=2) * 1.6) * 2)
    d = 0.9
    whirr = osc(sweep(80, 400, d), d, "saw") * 0.4 + osc(sweep(160, 800, d), d, "square") * 0.15
    whirr = lp(whirr, 2500) * env(d, 0.1, 0.7, s=0.2, r=0.1) * (0.7 + 0.3 * osc(sweep(20, 45, d), d, "square"))
    clunks = mix(*[at(mix(np.tanh(impact(1.1) * 1.5) * 0.5, metal_ring(600 + 120 * j, 0.25, 15) * 0.3), t0, 1.2)
                   for j, t0 in enumerate((0.25, 0.5, 0.8))])
    return finish(reverb(mix(slam, at(mix(whirr, clunks), 0.6, total)), 1.2, 0.3, 3500))

def fake_death():
    total = 6.0
    fall = boss_death()[:int(SR * 2.6)] * taper(int(SR * 2.6), 0.4)   # starts exactly like a real boss death
    beat = lambda: osc(sweep(70, 40, 0.16), 0.16) * env(0.16, 0.001, 0.14, curve=2)
    hb = mix(*[at(beat() * g, t0, 1.8) for t0, g in ((0.0, 0.25), (0.22, 0.18), (0.9, 0.4), (1.12, 0.3))])
    return finish(mix(at(fall, 0, total), at(hb, 4.0, total)))

def unbound_roar():
    total = 4.0
    d = 2.8; k = np.linspace(0, 1, int(SR * d))
    curve = 55 * (1 + 0.5 * np.sin(np.pi * k ** 0.7))
    layers = mix(monster(curve, d, "oh", "ah", throat=0.62, size=1.2),
                 monster(curve * 1.5, d, "ah", "uh", throat=0.7) * 0.6,
                 monster(curve * 0.75, d, "uh", "oh", throat=0.55) * 0.8)
    layers *= env(d, 0.15, 2.5, curve=1.1)
    rumble = thunder(3.2) * 0.9
    choir = sum(formant_voice(f, d, ((700, 5, 1.0), (1100, 6, 0.6), (2500, 8, 0.2)), 0.1) for f in (110.0, 130.8, 164.8))
    choir = choir * env(d, 1.0, 1.7, curve=1.3) * 0.35
    return finish(reverb(np.tanh(mix(at(layers, 0, total), at(rumble, 0, total), at(choir, 0.3, total)) * 1.3), 2.0, 0.35, 3000))

def unbound_mode():
    total = 1.8
    gear = mix(*[at(mix(np.tanh(impact(0.9) * 1.6) * 0.6, metal_ring(420 + 90 * j, 0.3, 12) * 0.35), t0, 0.8)
                 for j, t0 in enumerate((0.0, 0.12, 0.3))])
    grind = bandpass_sweep(noise(0.45), 300, 700, q=1.5) * env(0.45, 0.02, 0.4) * 0.5
    sting = brass((73.4, 77.8, 110.0), 1.2, 2000) * env(1.2, 0.01, 1.1, curve=1.4) * 1.0     # D, Eb, A: a dark cluster
    return finish(reverb(mix(at(mix(gear, grind), 0, total), at(sting, 0.32, total)), 1.2, 0.3, 3500))

def king_revive():
    total = 5.2
    # 1) heartbeat speeds up out of the silence
    beat = lambda: osc(sweep(75, 40, 0.16), 0.16) * env(0.16, 0.001, 0.14, curve=2)
    hb = np.zeros(int(SR * 2.4)); t0 = 0.0; gap = 0.55; g = 0.35
    while t0 < 2.2:
        for off, gg in ((0, 1.0), (0.17 * gap / 0.55, 0.7)):
            p = int(SR * (t0 + off)); b = beat() * g * gg
            hb[p:p + len(b)] += b[:len(hb) - p]
        t0 += gap; gap = max(gap * 0.82, 0.16); g = min(g * 1.15, 1.2)
    # 2) everything is sucked back into the body: reverse swell + choir and brass crescendo
    sw = 2.4; k = np.linspace(0, 1, int(SR * sw))
    suck = bandpass_sweep(noise(sw), 200, 5000, q=1.2) * k ** 3 * 1.0
    choir = sum(formant_voice(f, sw, ((700, 5, 1.0), (1100, 6, 0.6), (2500, 8, 0.2)), 0.1) for f in (98.0, 146.8, 196.0, 233.1))
    choir *= k ** 2.2 * 0.45
    rise = brass((49.0, 73.4, 98.0), sw, 2600) * k ** 2.5 * 0.8
    # 3) the revival burst
    burst = np.tanh(mix(impact(0.4) * 1.5, osc(sweep(70, 22, 2.0), 2.0) * env(2.0, 0.001, 1.8, curve=1.8) * 2.0,
                        lp(noise(1.6), 500) * env(1.6, 0.001, 1.3, curve=2) * 1.4, electric(0.6) * env(0.6, 0.001, 0.55)) * 2.2)
    ring = sum(bell(f, 2.0) for f in (196.0, 293.7, 392.0)) * 0.25
    x = mix(at(hb, 0, total), at(mix(suck, choir, rise), 0.3, total), at(mix(burst, ring), 2.7, total))
    return finish(reverb(x, 1.8, 0.35, 3500))

# ---------- group 7: fighter tricks ----------
def maneuver_ready():
    d = 0.6
    scrape = bandpass_sweep(noise(d), 3500, 7000, q=4) * env(d, 0.05, 0.45, curve=1.5) * 0.7
    ring = metal_ring(2400, 0.6, 7) * 0.4
    return finish(reverb(mix(scrape, at(ring, 0.18, d + 0.1)), 0.5, 0.2, 7000), -3)

def action_surge():
    total = 1.2; d = 0.45; k = np.linspace(0, 1, int(SR * d))
    shout = creature(150 * (1 + 0.6 * k), d, "ah", "eh", growl=0.8, breath=0.5, throat=0.95) * env(d, 0.02, 0.4, curve=1.2)
    swell = brass((110.0, 164.8, 220.0), 0.9, 2600) * env(0.9, 0.3, 0.55, curve=1.4) * 0.6
    hit = np.tanh(impact(0.7) * 1.6)
    whoosh = bandpass_sweep(noise(0.5), 400, 3000, q=1.5) * env(0.5, 0.35, 0.15) * 0.6
    return finish(reverb(mix(at(whoosh, 0, total), at(swell, 0.05, total), at(np.tanh(shout * 2.5) * 0.8, 0.3, total), at(hit, 0.32, total)), 0.8, 0.25))

def parry_ready():
    total = 0.6
    leather = bandpass_sweep(noise(0.12), 800, 1800, q=1.5) * env(0.12, 0.01, 0.1) * 0.5
    clank = mix(np.tanh(impact(1.1) * 1.2) * 0.5, metal_ring(680, 0.45, 8) * 0.55)
    return finish(reverb(mix(leather, at(clank, 0.08, total)), 0.4, 0.2), -3)

def rally():
    total = 1.3
    horn = lambda f, dd: lp(sum(osc(f * c, dd, "saw") for c in (0.997, 1.0, 1.004)) / 3, 2200) * env(dd, 0.04, dd * 0.9, s=0.6, r=0.1)
    x = mix(at(horn(392.0, 0.28), 0, total), at(horn(523.3, 0.7), 0.26, total))
    glow = sum(osc(f, 1.0) for f in (1046.5, 1318.5)) / 2 * env(1.0, 0.3, 0.6) * 0.15
    return finish(reverb(mix(x, at(glow, 0.3, total), at(shimmer(1.0, 4000, 8000, 20, 0.12), 0.3, total)), 1.0, 0.28, 6000), -2)


SOUNDS = {
    "ui_click": ui_click, "torch_on": torch_on, "firebolt": firebolt,
    "fireball": fireball, "ray_of_frost": ray_of_frost, "warden_laser": warden_laser,
    "level_up": level_up, "pickup_legendary": pickup_legendary,
    "ui_hover": ui_hover, "ui_open": ui_open, "ui_error": ui_error, "menu_start": menu_start,
    "sword_hit_1": lambda: sword_hit(0), "sword_hit_2": lambda: sword_hit(1), "sword_hit_3": lambda: sword_hit(2),
    "sword_miss_1": lambda: sword_miss(0), "sword_miss_2": lambda: sword_miss(1),
    "bow_shot": bow_shot, "crit": crit, "sneak_attack": sneak_attack, "hide": hide, "spotted": spotted,
    "player_hurt_1": lambda: player_hurt(0), "player_hurt_2": lambda: player_hurt(1),
    "player_death": player_death, "potion": potion, "pickup": pickup, "pickup_rare": pickup_rare,
    "equip": equip, "discard": discard, "stat_point": stat_point, "rest": rest,
    "spell_cast": spell_cast, "magic_missile": magic_missile, "scorching_ray": scorching_ray,
    "misty_step": misty_step, "sleep": sleep, "hold": hold, "haste": haste,
    "vampiric_touch": vampiric_touch, "sunbeam": sunbeam, "ice_storm": ice_storm, "cone_of_cold": cone_of_cold,
    "torch_off": torch_off, "wire_power": wire_power, "gate_rotate": gate_rotate, "door_open": door_open,
    "door_locked": door_locked, "plaque_read": plaque_read, "stairs": stairs,
    "goblin_hit": goblin_hit, "goblin_death": goblin_death, "skeleton_hit": skeleton_hit,
    "skeleton_death": skeleton_death, "orc_hit": orc_hit, "orc_death": orc_death,
    "enemy_hit": enemy_hit, "enemy_death": enemy_death,
    "boss_intro": boss_intro, "boss_death": boss_death, "warden_shield_break": warden_shield_break,
    "warden_teleport": warden_teleport, "shade_snuff": shade_snuff, "lantern_blaze": lantern_blaze,
    "ymir_spell": ymir_spell, "ymir_wave": ymir_wave, "ymir_stun": ymir_stun, "ward_shatter": ward_shatter,
    "altair_lightning": altair_lightning, "smo_slam": smo_slam, "bit_swap": bit_swap,
    "duo_empower": duo_empower, "throne_slam": throne_slam, "fake_death": fake_death,
    "unbound_roar": unbound_roar, "king_revive": king_revive,
    "maneuver_ready": maneuver_ready, "action_surge": action_surge, "parry_ready": parry_ready, "rally": rally, "unbound_mode": unbound_mode,
}

if __name__ == "__main__":
    # python3 sfx_synth.py OUTDIR [name ...] [--reel REEL.wav]
    args = sys.argv[1:]; out = args.pop(0) if args else "."
    reel_path = None
    if "--reel" in args:
        k = args.index("--reel"); reel_path = args[k + 1]; del args[k:k + 2]
    names = args or list(SOUNDS)
    os.makedirs(out, exist_ok=True)
    reel = []
    for name in names:
        rng = np.random.default_rng(sum(map(ord, name)))
        globals()["rng"] = rng                       # same sound every run
        x = SOUNDS[name]()
        wavfile.write(os.path.join(out, name + ".wav"), SR, (x * 32767).astype(np.int16))
        reel += [x, np.zeros(int(SR * 0.6))]
        print(f"{name:18s} {len(x)/SR:.2f}s")
    if reel_path:
        wavfile.write(reel_path, SR, (np.concatenate(reel) * 32767).astype(np.int16))
