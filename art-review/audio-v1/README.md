# Pocket Armor — sound review

Play `pocket-armor-sound-reel.wav` for the designed sound set. It is a 26-second stereo arrangement of the same source effects used in the game.

| Time | Sound |
| --- | --- |
| 0–4 s | Menu, tank selection, match start |
| 4–10 s | The eight cannons in selection order, with quiet treads underneath |
| 10–12 s | Ricochet variations |
| 12–15 s | Mine placement, arming, explosion |
| 15–18 s | Cannon, reload latch, tank explosion |
| 18–20 s | Pause and resume |
| 20–23 s | Victory |
| 23–26 s | Defeat |

`runtime-mix.wav` is a separate capture of the actual Godot audio test, including deliberate overlapping effects to test the mix. `runtime-validation.json` records the functional checks; `asset-validation.json` records source-file integrity and level checks. The preview arrangement is for listening; the runtime recording is evidence of integration, not a polished demo.

Source and provenance: `tools/build_audio.py` and `assets/audio/manifest.json`.
