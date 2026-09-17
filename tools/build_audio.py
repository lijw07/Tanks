"""Rebuild Pocket Armor's original toybox sound set. Python standard library only."""

from array import array
from pathlib import Path
import hashlib
import json
import math
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio"
REVIEW = ROOT / "art-review/audio-v1"
RATE = 44100
TAU = math.tau
assets = {}
manifest = []


def silence(seconds):
    return [0.0] * round(seconds * RATE)


def add(dst, src, at=0.0, gain=1.0):
    start = round(at * RATE)
    for i in range(min(len(src), len(dst) - start)):
        dst[start + i] += src[i] * gain


def resonator(seconds, frequency, decay, partials=(1.0, 2.32, 4.18), bend=0.0):
    result = silence(seconds)
    phase = 0.0
    for i in range(len(result)):
        t = i / RATE
        phase += TAU * frequency * (1 + bend * math.exp(-t * 35)) / RATE
        attack = min(1.0, t / 0.0025)
        result[i] = attack * sum(
            math.sin(phase * ratio) * math.exp(-t / (decay / (1 + j * 0.75))) / (1 + j * 2)
            for j, ratio in enumerate(partials)
        )
    return result


def thump(seconds, high, low, decay):
    phase = 0.0
    result = silence(seconds)
    for i in range(len(result)):
        t = i / RATE
        phase += TAU * (low + (high - low) * math.exp(-t * 38)) / RATE
        result[i] = math.sin(phase) * math.exp(-t / decay) * min(1, t / .0018)
    return result


def noise(seconds, seed, decay, cutoff, highpass=False):
    rng = random.Random(seed)
    result = silence(seconds)
    low = 0.0
    alpha = 1 - math.exp(-TAU * cutoff / RATE)
    for i in range(len(result)):
        t = i / RATE
        sample = rng.uniform(-1, 1)
        low += alpha * (sample - low)
        result[i] = (sample - low if highpass else low) * math.exp(-t / decay) * min(1, t / .001)
    return result


def write_wav(path, samples, channels=1):
    pcm = array("h", [round(max(-.999, min(.999, x)) * 32767) for x in samples])
    import sys
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())


def save(name, samples, description, peak=.72, loop=False):
    if not loop:
        # No DC offset or abrupt clip boundaries, including layered delayed hits.
        dc = sum(samples) / len(samples)
        samples = [x - dc for x in samples]
        edge = min(round(RATE * .014), len(samples) // 3)
        for i in range(edge):
            samples[i] *= min(1, i / (RATE * .001))
            samples[-1 - i] *= i / edge
    gain = peak / max(abs(x) for x in samples)
    samples = [x * gain for x in samples]
    path = OUT / (name + ".wav")
    write_wav(path, samples)
    assets[name] = samples
    rms = math.sqrt(sum(x*x for x in samples) / len(samples))
    manifest.append({"id": name, "file": str(path.relative_to(ROOT)), "description": description,
                     "seconds": round(len(samples) / RATE, 4), "channels": 1, "sample_rate": RATE,
                     "bits": 16, "peak_dbfs": round(20 * math.log10(peak), 2),
                     "rms_dbfs": round(20 * math.log10(rms), 2), "loop": loop,
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})


def cannon(index, high, low, decay, ring):
    samples = silence(.48 + decay)
    add(samples, thump(.45, high, low, decay), gain=1.0)
    add(samples, noise(.27, 100 + index, .032, 4300), gain=.75)
    add(samples, noise(.4, 200 + index, .075, 650), at=.008, gain=.6)
    add(samples, resonator(.32, ring, .040, (1, 1.53, 2.81), .18), gain=.25)
    add(samples, resonator(.12, 340 + index * 19, .015), at=.115, gain=.08)
    return samples


def chime(notes, step=.1, decay=.13):
    result = silence(step * (len(notes) - 1) + decay * 5)
    for i, midi in enumerate(notes):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        add(result, resonator(decay * 5, frequency, decay, (1, 2, 3.01)), at=i * step, gain=.75)
        add(result, noise(.04, midi, .008, 2200), at=i * step, gain=.09)
    return result


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    specs = [(270, 94, .068, 720), (230, 80, .082, 630), (195, 58, .115, 410),
             (310, 108, .055, 830), (340, 87, .062, 1120), (245, 83, .072, 670),
             (172, 48, .145, 355), (205, 69, .100, 510)]
    names = ["Azure Scout", "Mint Cruiser", "Red Bulldog", "Gold Sprinter", "Violet Needle",
             "Ivory Duelist", "Orange Mortar", "Slate Command"]
    for i, spec in enumerate(specs):
        save("cannon_%02d" % i, cannon(i, *spec), names[i] + ": layered air pop, shell thump and barrel rattle")

    for i in range(3):
        s = silence(.4)
        add(s, resonator(.39, 1160 + i * 167, .065, (1, 1.43, 2.79), -.28), gain=.55)
        add(s, noise(.07, 410 + i, .01, 3700), gain=.3)
        add(s, thump(.14, 410, 220, .019), gain=.25)
        save("ricochet_%02d" % i, s, "Short spring-metal ping with a pitched glancing impact", peak=.58)

    for i in range(3):
        s = silence(1.15)
        add(s, thump(.65, 195 - i * 12, 45 + i * 3, .155), gain=.95)
        add(s, noise(.92, 520 + i, .18, 1400), gain=1.6)
        add(s, noise(.22, 550 + i, .031, 6100), gain=.7)
        for j in range(6):
            add(s, resonator(.25, 340 + j * 217 + i * 31, .028, (1, 1.87, 3.1)),
                at=.08 + j * .059, gain=.14 * (1 - j / 8))
        save("explosion_%02d" % i, s, "Rounded toy-tank burst with tumbling metal debris")

    s = silence(.32)
    add(s, thump(.18, 250, 100, .036), gain=.7)
    add(s, resonator(.16, 590, .025), at=.018, gain=.38)
    add(s, noise(.045, 640, .007, 2800), at=.085, gain=.4)
    save("mine_place", s, "Mine drops with a hollow clunk and latch click", peak=.60)
    save("mine_arm", chime([79, 84], .07, .045), "Small two-note armed indicator", peak=.42)
    s = silence(1.3)
    add(s, assets["explosion_02"], gain=.9)
    add(s, thump(.7, 136, 38, .19), gain=.62)
    add(s, noise(.8, 703, .11, 900), at=.06, gain=.42)
    save("mine_burst", s, "Deeper ground-level mine burst")
    s = silence(.19)
    add(s, noise(.055, 711, .01, 3400), gain=.7)
    add(s, resonator(.15, 440, .026, (1, 1.8, 3.7)), at=.048, gain=.4)
    save("reload_ready", s, "Quiet bolt closure when the player's cannon reloads", peak=.38)

    save("ui_hover", chime([79], decay=.020), "Soft wooden menu tick", peak=.30)
    save("ui_confirm", chime([72, 79], .055, .055), "Rounded rising confirmation", peak=.48)
    save("ui_back", chime([74, 69], .05, .047), "Gentle descending back cue", peak=.42)
    s = chime([60, 67, 72], .045, .085)
    add(s, thump(.15, 180, 100, .029), gain=.4)
    save("tank_select", s, "Playful mechanical lock-in chord", peak=.49)
    save("pause", chime([76, 72], .07, .06), "Soft pause cue", peak=.40)
    save("resume", chime([72, 76], .07, .06), "Soft resume cue", peak=.40)
    save("match_start", chime([60, 67, 72, 79], .115, .16), "Four-note Pocket Armor launch motif", peak=.54)
    save("victory", chime([60, 64, 67, 72, 76, 79], .12, .27), "Bright toybox victory fanfare", peak=.59)
    save("defeat", chime([67, 63, 60, 55], .19, .22), "Warm, short descending round-end phrase", peak=.52)
    save("player_down", chime([60, 55], .16, .13), "Brief lower cue entering spectator mode", peak=.40)

    # Integer-frequency oscillators give an exact two-second cyclic motor/tread loop.
    s = silence(2)
    rng = random.Random(820)
    phases = [rng.random() * TAU for _ in range(18)]
    for i in range(len(s)):
        t = i / RATE
        motor = sum(math.sin(TAU * 51 * h * t) / (h * h) for h in range(1, 7))
        rattle = sum(math.sin(TAU * (370 + h * 61) * t + phases[h]) / 18 for h in range(18))
        tread = ((1 + math.cos(TAU * 17 * t)) * .5) ** 14
        s[i] = .5 * motor * (1 + .14 * math.sin(TAU * 17 * t)) + .34 * tread * rattle
    save("treads_loop", s, "Seamless little motor with lightly rattling caterpillar tracks", peak=.5, loop=True)

    # Stereo listening reel; the same untouched assets are used in-game.
    timeline = [(0.2, "ui_hover"), (.55, "ui_hover"), (.95, "ui_confirm"), (1.6, "tank_select"),
                (2.5, "match_start")]
    timeline += [(4.0 + i * .72, "cannon_%02d" % i) for i in range(8)]
    timeline += [(10.0, "ricochet_00"), (10.6, "ricochet_01"), (11.2, "ricochet_02"),
                 (12.0, "mine_place"), (13.1, "mine_arm"), (13.9, "mine_burst"),
                 (15.5, "cannon_00"), (16.2, "reload_ready"), (17.0, "explosion_00"),
                 (18.4, "pause"), (19.0, "resume"), (19.8, "victory"), (23.0, "defeat")]
    left, right = silence(26), silence(26)
    for i, (at, name) in enumerate(timeline):
        pan = ((i % 3) - 1) * .25
        add(left, assets[name], at, .8 * math.sqrt((1 - pan) / 2))
        add(right, assets[name], at, .8 * math.sqrt((1 + pan) / 2))
    for at in [4., 6., 8.]:
        motor = [x * .16 for x in assets["treads_loop"]]
        edge = round(.05 * RATE)
        for i in range(edge):
            motor[i] *= i / edge
            motor[-1-i] *= i / edge
        add(left, motor, at)
        add(right, motor, at)
    write_wav(REVIEW / "pocket-armor-sound-reel.wav", [v for pair in zip(left, right) for v in pair], 2)
    payload = {"name": "Pocket Armor - Toybox Audio v1", "generator": "tools/build_audio.py",
               "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "provenance": "Original deterministic procedural synthesis. No recordings, third-party samples, AI service, or paid provider used.",
               "usage": "Created for this project; no third-party sample attribution or sample license obligations.",
               "specification": "Short, rounded low-poly toy-tank effects; readable phone-speaker transients, gentle menu percussion, no voice or realistic firearm recordings. Mono PCM16 44.1kHz. Peaks below -2.8dBFS. Seamless motor loop.",
               "assets": manifest, "reel_timeline": [{"seconds": t, "id": n} for t, n in timeline]}
    (OUT / "manifest.json").write_text(json.dumps(payload, indent=2) + "\n")
    print(f"Built {len(manifest)} WAV assets; {sum((OUT / (a['id'] + '.wav')).stat().st_size for a in manifest):,} bytes.")


if __name__ == "__main__":
    build()
