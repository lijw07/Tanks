# Pocket Armor music review

`menu-and-battle-preview.wav` contains 16 seconds of **Rollout Club**, a one-second gap, then 16 seconds of **Tin Track Rally**. The game uses the complete 32-bar loops, with a crossfade when entering or leaving a match.

- Menu: 104 BPM, 73.846 seconds; plucked melody, mallets, warm keys, bass and light percussion.
- Battle: 128 BPM, 60 seconds; a faster groove, reed melody, bass, syncopated plucks and drums.

Both compositions, arrangements, instruments and percussion were generated locally from their original score in `tools/build_music.py`. No pre-existing songs or third-party samples were used.

The original effects mix is louder by 5 dB (4 dB for menu cues). The Music bus sits at -4 dB, passes through the same master Volume slider, softens during pause/results, and makes room for round-start and end cues.

`runtime-mix.wav` captures the actual Godot test. `runtime-validation.json` records transition/loop/mix checks, and `asset-validation.json` records file integrity, levels, loop seams and exported import sizes. The tests use native CoreAudio; browser and mobile-device playback still need testing on those platforms.
