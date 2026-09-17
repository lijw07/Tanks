"""Compose and render Pocket Armor's original looping score. Requires NumPy."""

from functools import lru_cache
from pathlib import Path
import hashlib
import json
import math
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/music"
REVIEW = ROOT / "art-review/music-v1"
RATE = 32000
TAU = math.tau


@lru_cache(maxsize=512)
def voice(kind, midi, seconds):
    t = np.arange(round((seconds + .26) * RATE)) / RATE
    f = 440 * 2 ** ((midi - 69) / 12)
    phase = TAU * f * t
    release = np.clip((seconds + .2 - t) / .2, 0, 1)
    if kind == "pluck":
        tone = sum(np.sin(phase * h + .09 * np.sin(phase * 1.002)) * np.exp(-t * (3 + h * 2)) / h**1.3 for h in range(1, 8))
        env = (1 - np.exp(-t * 800)) * release
    elif kind == "mallet":
        tone = np.sin(phase) + .35 * np.sin(phase * 3.995) * np.exp(-t * 22) + .1 * np.sin(phase * 9.97) * np.exp(-t * 35)
        env = (1 - np.exp(-t * 1100)) * np.exp(-t * 4.8) * release
    elif kind == "keys":
        tone = np.sin(phase + .5 * np.sin(phase * 2) * np.exp(-t * 9)) + .2 * np.sin(phase * 2.002) * np.exp(-t * 4)
        env = (1 - np.exp(-t * 180)) * np.exp(-t * 2.2) * release
    elif kind == "reed":
        phase += .013 * np.sin(TAU * 5 * t) * np.clip(t * 10, 0, 1)
        tone = np.sin(phase) + .27 * np.sin(phase * 2) + .15 * np.sin(phase * 3) + .04 * np.sin(phase * 5)
        env = (1 - np.exp(-t * 65)) * (.7 + .3 * np.exp(-t * 10)) * release
    else:
        tone = np.sin(phase) + .32 * np.sin(phase * 2) + .13 * np.sin(phase * 3)
        env = (1 - np.exp(-t * 240)) * np.exp(-t * 2.8) * release
    fade = np.minimum(1, (len(t) - 1 - np.arange(len(t))) / (RATE * .006))
    return (tone * env * fade).astype(np.float32)


@lru_cache(maxsize=16)
def drum(kind):
    rng = np.random.default_rng(713 + sum(map(ord, kind)))
    t = np.arange(round(.65 * RATE)) / RATE
    n = rng.uniform(-1, 1, len(t))
    low = np.convolve(n, np.ones(8) / 8, "same")
    if kind == "kick":
        phase = TAU * (49 * t + 92 * (1 - np.exp(-t * 38)) / 38)
        s = np.sin(phase) * np.exp(-t * 16) + low * np.exp(-t * 180) * .16
    elif kind == "snare":
        s = (n - low) * np.exp(-t * 28) * .36 + np.sin(TAU * 185 * t) * np.exp(-t * 33) * .3
    elif kind == "hat":
        s = (n - low) * np.exp(-t * 95) * .22
    elif kind == "shaker":
        s = (n - low) * np.exp(-t * 60) * np.sin(np.minimum(t * 80, math.pi / 2)) * .17
    elif kind == "rim":
        s = (np.sin(TAU * 1120 * t) + .45 * np.sin(TAU * 1790 * t)) * np.exp(-t * 115) * .32
    else:
        phase = TAU * (85 * t + 80 * (1 - np.exp(-t * 22)) / 22)
        s = np.sin(phase) * np.exp(-t * 17) + low * np.exp(-t * 30) * .3
    s *= np.minimum(1, t * 1800)
    s *= np.clip((.64 - t) / .04, 0, 1)
    return s.astype(np.float32)


def place(track, sound, at, gain, pan=0):
    start = round(at * RATE) % len(track)
    gains = np.array([math.sqrt((1 - pan) / 2), math.sqrt((1 + pan) / 2)]) * gain
    stereo = sound[:, None] * gains
    count = min(len(sound), len(track) - start)
    track[start:start + count] += stereo[:count]
    if count < len(sound):
        track[:len(sound) - count] += stereo[count:]


def write(path, track):
    pcm = np.round(np.clip(track, -.999, .999) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())


def compose(battle=False):
    bpm = 128 if battle else 104
    beat = 60 / bpm
    track = np.zeros((round(32 * 4 * beat * RATE), 2), dtype=np.float32)
    chords = {"C": (48, [60, 64, 67, 71]), "Am": (45, [60, 64, 69, 72]),
              "F": (41, [60, 65, 69, 72]), "G": (43, [59, 62, 67, 69]),
              "Dm": (38, [60, 62, 65, 69]), "Em": (40, [59, 64, 67, 71])}
    progression = (["Am", "Am", "F", "G", "C", "G", "Dm", "Em",
                    "F", "G", "Am", "Am", "Dm", "F", "G", "Em"] if battle else
                   ["C", "C", "Am", "Am", "F", "F", "G", "G",
                    "Dm", "G", "Em", "Am", "F", "C", "Dm", "G"])
    menu_lines = [
        [(0, 76, .5), (.75, 79, .35), (1.5, 81, .35), (2.25, 79, .35), (3, 76, .7)],
        [(.5, 74, .5), (1.25, 72, .75), (3, 74, .4), (3.5, 76, .35)],
        [(0, 76, .6), (1, 72, .5), (2, 69, .4), (2.75, 72, .9)],
        [(.5, 74, .5), (1.25, 76, .45), (2, 79, 1.25)],
        [(0, 77, .5), (.75, 81, .5), (1.5, 79, .4), (2.25, 77, .4), (3, 76, .5)],
        [(.5, 72, .6), (1.5, 69, .5), (2.5, 72, 1)],
        [(0, 74, .5), (.75, 79, .5), (1.5, 77, .5), (2.5, 74, .5)],
        [(0, 71, .6), (1, 74, .4), (1.75, 76, .45), (2.5, 74, .9)],
    ]
    battle_lines = [
        [(0, 76, .35), (.75, 76, .3), (1.5, 79, .35), (2, 81, .5), (3, 79, .45)],
        [(.5, 76, .35), (1, 72, .45), (2, 74, .3), (2.75, 76, .8)],
        [(0, 77, .4), (.75, 76, .35), (1.5, 72, .45), (2.5, 69, .65)],
        [(.25, 71, .35), (1, 74, .35), (1.75, 79, .5), (3, 77, .45)],
        [(0, 76, .35), (.75, 79, .4), (1.5, 84, .4), (2.25, 83, .35), (3, 79, .5)],
        [(.5, 74, .4), (1.25, 71, .45), (2, 74, .35), (3, 79, .5)],
        [(0, 77, .35), (.75, 74, .45), (1.5, 69, .45), (2.5, 72, .8)],
        [(0, 71, .3), (.75, 74, .35), (1.5, 76, .7), (3, 71, .5)],
    ]
    lines = battle_lines if battle else menu_lines
    for bar in range(32):
        root, chord = chords[progression[bar % 16]]
        offset = bar * 4
        bridge = 16 <= bar < 24
        for step in range(8):
            timing = step * .5 + (.035 if step % 2 and not battle else 0)
            note = chord[(step + (bar % 2) * 2) % 4] + (12 if bar >= 24 and step % 4 == 3 else 0)
            place(track, voice("pluck", note, round(beat * .8, 3)), (offset + timing) * beat,
                  .20 if battle else .26, -.35 if step % 2 else .35)
        for step in ([0, 1.5, 2.5] if battle else [0, 2]):
            for j, note in enumerate(chord):
                place(track, voice("keys", note - 12, round(beat * (1 if battle else 1.4), 3)),
                      (offset + step + j * .018) * beat, .075, (j - 1.5) * .2)
        bass_pattern = [(0, 0, .7), (1.5, 7, .35), (2, 12, .6), (3, 7, .35), (3.5, 12, .25)] if battle else [(0, 0, 1), (1.5, 7, .5), (2.5, 12, .7), (3.5, 7, .3)]
        for step, interval, length in bass_pattern:
            place(track, voice("bass", root - 12 + interval, round(length * beat, 3)), (offset + step) * beat, .43 if battle else .35)
        for step, note, length in lines[bar % 8]:
            if bridge:
                note -= 12
            elif bar >= 24 and bar % 4 == 3:
                note += 12
            place(track, voice("mallet" if not battle or bridge else "reed", note, round(length * beat, 3)),
                  (offset + step) * beat, .31 if battle else .4, -.12)
            if not bridge and bar % 4 == 2:
                place(track, voice("mallet", note - 12, round(length * beat, 3)), (offset + step + .04) * beat, .13, .3)
        for step in ([0, 1.5, 2, 3.25] if battle else [0, 2.5]):
            place(track, drum("kick"), (offset + step) * beat, .54 if battle else .38)
        for step in [1, 3]:
            place(track, drum("snare" if battle and not bridge else "rim"), (offset + step) * beat, .4 if battle else .3, -.08)
        for step in range(8):
            place(track, drum("hat" if battle else "shaker"), (offset + step * .5) * beat,
                  (.34 if step % 2 else .2) * (.65 if bridge else 1), .4)
        if bar % 8 == 7:
            for step in [3.0, 3.5, 3.75]:
                place(track, drum("tom"), (offset + step) * beat, .24 if battle else .13, (step - 3.3) * .9)
    dry = track.copy()
    for seconds, gain in [(.083, .11), (.137, .08), (.223, .055), (.331, .035)]:
        track += np.roll(dry[:, ::-1], round(seconds * RATE), axis=0) * gain
    track -= track.mean(axis=0)
    track = np.tanh(track * 1.4)
    track *= .84 / np.max(np.abs(track))
    return track, bpm


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    (REVIEW / ".gdignore").touch()
    entries = []
    previews = []
    for name, title, battle in [("menu_theme", "Rollout Club", False), ("battle_theme", "Tin Track Rally", True)]:
        track, bpm = compose(battle)
        path = OUT / (name + ".wav")
        write(path, track)
        jump = float(np.max(np.abs(track[-1] - track[0])))
        assert jump < .04, jump
        assert np.max(np.abs(track)) < .85
        assert np.max(np.abs(track.mean(axis=0))) < .002
        entries.append({"id": name, "title": title, "file": str(path.relative_to(ROOT)), "bpm": bpm,
                        "bars": 32, "seconds": round(len(track) / RATE, 6), "frames": len(track),
                        "sample_rate": RATE, "channels": 2, "bits": 16, "loop": True,
                        "peak_dbfs": round(20 * math.log10(float(np.max(np.abs(track)))), 3),
                        "rms_dbfs": round(20 * math.log10(float(np.sqrt(np.mean(track**2)))), 3),
                        "loop_boundary_jump": round(jump, 6),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        excerpt = track[:16 * RATE].copy()
        excerpt[:RATE // 5] *= np.linspace(0, 1, RATE // 5)[:, None]
        excerpt[-RATE:] *= np.linspace(1, 0, RATE)[:, None]
        previews.append(excerpt)
        print(title, entries[-1], flush=True)
    write(REVIEW / "menu-and-battle-preview.wav", np.concatenate([previews[0], np.zeros((RATE, 2)), previews[1]]))
    manifest = {"generator": "tools/build_music.py", "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "provenance": "Original melody, harmony, arrangement, instrument synthesis and percussion created locally for Pocket Armor. No third-party samples, existing song, external generator or paid service.",
                "licensing": "Follows the project's existing licensing status; no new third-party sample license obligations.",
                "render": "NumPy synthesis; PCM16 stereo at 32000Hz. Note tails and room reflections wrap across the exact 32-bar loop. Godot imports compress to QOA.",
                "tracks": entries}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
