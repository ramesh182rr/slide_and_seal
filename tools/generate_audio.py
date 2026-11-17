"""Synthesises every sound in Slide & Seal from code (Python standard library only), so all audio
is original and project-owned: no samples, no licences.

    python3 tools/generate_audio.py game/assets/audio

Writes 16-bit mono WAV files: short effects (44.1 kHz) in sfx/, and one seamless 16-second ambient
loop per world (22.05 kHz) in music/. Deterministic: the same script always writes the same files.
Re-run after changing a sound, then let Godot re-import.
"""
import math, os, random, struct, sys, wave

OUT = sys.argv[1]
SFX_RATE = 44100
MUSIC_RATE = 22050
TAU = math.tau


def write(path, samples, rate, peak=0.9):
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))
    print("wrote", path, f"{len(samples) / rate:.2f}s")


def silence(seconds, rate):
    return [0.0] * int(seconds * rate)


def add(target, source, at=0.0, rate=SFX_RATE, gain=1.0):
    start = int(at * rate)
    for i, s in enumerate(source):
        if start + i < len(target):
            target[start + i] += s * gain


def tone(freq, seconds, rate=SFX_RATE, decay=8.0, attack=0.004, sweep=1.0, shape="sine", overtone=0.0):
    """A pitched voice with an exponential decay. `sweep` multiplies the pitch from start to end."""
    out, phase = [], 0.0
    n = int(seconds * rate)
    for i in range(n):
        t = i / rate
        f = freq * (sweep ** (i / max(1, n - 1)))
        phase += TAU * f / rate
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "tri":
            v = 2.0 / math.pi * math.asin(math.sin(phase))
        else:  # soft square
            v = math.tanh(3.0 * math.sin(phase))
        if overtone:
            v += overtone * math.sin(phase * 2.76)  # bell-like inharmonic partial
        env = min(1.0, t / attack) * math.exp(-decay * t)
        out.append(v * env)
    return out


def noise(seconds, rate=SFX_RATE, decay=10.0, lowpass=0.2, attack=0.002, seed=1, highpass=0.0):
    """Filtered noise burst. `lowpass` is the one-pole coefficient (smaller = darker)."""
    rng = random.Random(seed)
    out, lp, hp_prev, hp = [], 0.0, 0.0, 0.0
    for i in range(int(seconds * rate)):
        t = i / rate
        white = rng.uniform(-1.0, 1.0)
        lp += lowpass * (white - lp)
        v = lp
        if highpass:
            hp = highpass * (hp + v - hp_prev)
            hp_prev = v
            v = hp
        out.append(v * min(1.0, t / attack) * math.exp(-decay * t))
    return out


def bell(freq, seconds, rate=SFX_RATE, decay=5.0):
    out = silence(seconds, rate)
    add(out, tone(freq, seconds, rate, decay, 0.003, overtone=0.35), 0, rate)
    add(out, tone(freq * 2.0, seconds, rate, decay * 1.8, 0.003), 0, rate, 0.3)
    add(out, tone(freq * 3.01, seconds, rate, decay * 2.6, 0.002), 0, rate, 0.12)
    return out


def sfx():
    d = os.path.join(OUT, "sfx")
    # UI tap: a tiny bright blip.
    s = silence(0.07, SFX_RATE)
    add(s, tone(1250, 0.07, decay=55, sweep=0.7))
    add(s, noise(0.02, decay=160, lowpass=0.6, seed=2), gain=0.25)
    write(f"{d}/tap.wav", s, SFX_RATE, 0.55)
    # Move committed: a soft wooden "tok".
    s = silence(0.14, SFX_RATE)
    add(s, tone(330, 0.14, decay=32, sweep=0.75, shape="tri"))
    add(s, noise(0.05, decay=80, lowpass=0.35, seed=3), gain=0.5)
    write(f"{d}/move.wav", s, SFX_RATE, 0.7)
    # Rejected: two low dull buzzes.
    s = silence(0.3, SFX_RATE)
    for at in (0.0, 0.13):
        add(s, tone(132, 0.12, decay=14, shape="square", sweep=0.92), at, gain=0.8)
    write(f"{d}/reject.wav", s, SFX_RATE, 0.5)
    # Run: the core powers up, a rising airy sweep.
    s = silence(0.42, SFX_RATE)
    add(s, tone(260, 0.42, decay=5, attack=0.05, sweep=3.2))
    add(s, tone(390, 0.42, decay=6, attack=0.08, sweep=3.2), gain=0.4)
    add(s, noise(0.4, decay=6, lowpass=0.08, attack=0.1, seed=4, highpass=0.9), gain=0.8)
    write(f"{d}/run.wav", s, SFX_RATE, 0.6)
    # Core step: a glassy tick (pitched per step in game).
    s = silence(0.12, SFX_RATE)
    add(s, tone(1568, 0.12, decay=38, overtone=0.25))
    add(s, tone(3136, 0.06, decay=70), gain=0.2)
    write(f"{d}/step.wav", s, SFX_RATE, 0.4)
    # Block lands: a weighty thud.
    s = silence(0.3, SFX_RATE)
    add(s, tone(120, 0.3, decay=16, sweep=0.45))
    add(s, noise(0.09, decay=45, lowpass=0.12, seed=5), gain=0.9)
    write(f"{d}/land.wav", s, SFX_RATE, 0.85)
    # Block slides / pushes: a short scrape.
    s = silence(0.22, SFX_RATE)
    add(s, noise(0.22, decay=11, lowpass=0.1, attack=0.03, seed=6, highpass=0.6))
    write(f"{d}/slide.wav", s, SFX_RATE, 0.5)
    # Gate moves: stone grinding, then a seat.
    s = silence(0.42, SFX_RATE)
    add(s, noise(0.3, decay=6, lowpass=0.06, attack=0.04, seed=7), gain=1.0)
    add(s, tone(82, 0.2, decay=20, sweep=0.6), 0.22, gain=0.9)
    add(s, noise(0.05, decay=70, lowpass=0.2, seed=8), 0.22, gain=0.5)
    write(f"{d}/gate.wav", s, SFX_RATE, 0.75)
    # Lever / switch: a two-stage mechanical click.
    s = silence(0.16, SFX_RATE)
    add(s, noise(0.02, decay=220, lowpass=0.7, seed=9), 0.0, gain=0.8)
    add(s, tone(900, 0.03, decay=120), 0.0, gain=0.5)
    add(s, noise(0.03, decay=140, lowpass=0.45, seed=10), 0.06, gain=1.0)
    add(s, tone(520, 0.08, decay=45, shape="tri"), 0.06, gain=0.7)
    write(f"{d}/switch.wav", s, SFX_RATE, 0.65)
    # Gravity / rotation: a deep swoosh.
    s = silence(0.5, SFX_RATE)
    add(s, noise(0.5, decay=5, lowpass=0.05, attack=0.14, seed=11, highpass=0.8))
    add(s, tone(180, 0.5, decay=5, attack=0.12, sweep=0.5), gain=0.5)
    write(f"{d}/turn.wav", s, SFX_RATE, 0.6)
    # Checkpoint: a two-note chime.
    s = silence(0.9, SFX_RATE)
    add(s, bell(659.25, 0.8, decay=5.5), 0.0)
    add(s, bell(987.77, 0.75, decay=5.0), 0.11, gain=0.8)
    write(f"{d}/checkpoint.wav", s, SFX_RATE, 0.6)
    # Seal complete: a rising arpeggio that blooms into a chord.
    s = silence(2.4, SFX_RATE)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        add(s, bell(f, 1.6, decay=2.6), i * 0.11, gain=0.8)
    for f in (523.25, 783.99, 1318.5):
        add(s, bell(f, 1.8, decay=1.8), 0.5, gain=0.45)
    add(s, noise(1.4, decay=2.2, lowpass=0.5, attack=0.2, seed=12, highpass=0.95), 0.45, gain=0.25)
    write(f"{d}/complete.wav", s, SFX_RATE, 0.8)
    # One star lights (pitched per star in game).
    s = silence(0.6, SFX_RATE)
    add(s, bell(1318.5, 0.6, decay=7.0))
    write(f"{d}/star.wav", s, SFX_RATE, 0.55)
    # Undo / restart: a falling blip.
    s = silence(0.16, SFX_RATE)
    add(s, tone(880, 0.16, decay=22, sweep=0.5, shape="tri"))
    write(f"{d}/undo.wav", s, SFX_RATE, 0.5)
    # Screen change: a soft airy whoosh.
    s = silence(0.28, SFX_RATE)
    add(s, noise(0.28, decay=9, lowpass=0.25, attack=0.06, seed=13, highpass=0.93))
    write(f"{d}/whoosh.wav", s, SFX_RATE, 0.35)


# World ambience: [file, root Hz, chord ratios, wind brightness, bell scale ratios, pulse Hz, colour]
WORLDS = [
    ("world_01", 146.83, (1.0, 1.5, 2.0, 2.5), 0.05, (2.0, 2.25, 2.5, 3.0, 3.375), 0.0, "soft"),
    ("world_02", 110.00, (1.0, 1.5, 2.0, 3.0), 0.12, (4.0, 4.5, 5.0, 6.0, 6.75), 0.0, "glass"),
    ("world_03", 82.41, (1.0, 1.498, 2.0, 2.378), 0.03, (2.0, 2.378, 2.67, 3.0), 1.0, "dark"),
    ("world_04", 92.50, (1.0, 1.5, 2.25, 2.83), 0.07, (3.0, 3.375, 4.0, 4.5, 5.66), 0.0, "glass"),
    ("world_05", 98.00, (1.0, 1.25, 1.5, 2.0), 0.04, (2.0, 2.5, 3.0, 3.75, 4.0), 0.0, "soft"),
    ("world_06", 103.83, (1.0, 1.189, 1.5, 2.0), 0.06, (2.378, 3.0, 3.56, 4.0), 2.0, "dark"),
    ("world_07", 65.41, (1.0, 1.06, 1.5, 2.0), 0.03, (2.0, 2.12, 3.0, 3.18), 0.5, "dark"),
]
LOOP_SECONDS = 16.0


def lock(freq):
    """Nearest frequency with a whole number of cycles in the loop, so the loop is seamless."""
    return round(freq * LOOP_SECONDS) / LOOP_SECONDS


def ambience(name, root, chord, wind, scale, pulse, colour, seed):
    rate = MUSIC_RATE
    n = int(LOOP_SECONDS * rate)
    out = [0.0] * n
    rng = random.Random(seed)
    # Pad: each chord tone is a pair of slightly detuned sines breathing on its own slow LFO.
    for k, ratio in enumerate(chord):
        for detune in (-1, 1):
            f = lock(root * ratio) + detune / LOOP_SECONDS  # one cycle apart: a 16 s beat
            lfo_cycles = 1 + (k + (detune > 0)) % 3
            lfo_phase = rng.uniform(0, TAU)
            gain = 0.5 / (1 + k * 0.6)
            for i in range(n):
                t = i / rate
                breath = 0.6 + 0.4 * math.sin(TAU * lfo_cycles * t / LOOP_SECONDS + lfo_phase)
                v = math.sin(TAU * f * t)
                if colour == "dark":
                    v = math.tanh(1.6 * v) * 0.8
                out[i] += v * breath * gain
    # A slow throb for the machine worlds.
    if pulse:
        f = lock(root * 0.5)
        for i in range(n):
            t = i / rate
            beat = 0.5 + 0.5 * math.sin(TAU * lock(pulse) * t - math.pi / 2)
            out[i] += math.sin(TAU * f * t) * (beat ** 3) * 0.45
    # Wind: looped filtered noise (the tail is cross-faded into the head).
    fade = int(1.5 * rate)
    raw, lp = [], 0.0
    for i in range(n + fade):
        lp += wind * (rng.uniform(-1, 1) - lp)
        raw.append(lp)
    for i in range(n):
        v = raw[i]
        if i < fade:
            a = i / fade
            v = raw[i] * a + raw[n + i] * (1 - a)
        t = i / rate
        swell = 0.55 + 0.45 * math.sin(TAU * 2 * t / LOOP_SECONDS + 1.0)
        out[i] += v * swell * (1.6 if colour != "dark" else 2.4)
    # Sparse bells from the world's scale; tails wrap around the loop.
    notes = 7 if colour != "dark" else 4
    for j in range(notes):
        at = (j + rng.uniform(0.15, 0.85)) * LOOP_SECONDS / notes
        f = root * scale[rng.randrange(len(scale))]
        voice = bell(f, 3.5, rate, decay=1.4 if colour == "glass" else 1.9)
        start = int(at * rate)
        for i, s in enumerate(voice):
            out[(start + i) % n] += s * (0.28 if colour != "dark" else 0.18)
    write(os.path.join(OUT, "music", f"{name}.wav"), out, rate, 0.7)


sfx()
for index, world in enumerate(WORLDS):
    ambience(*world, seed=100 + index)
