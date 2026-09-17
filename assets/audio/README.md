# Pocket Armor audio

Original, locally synthesized sounds tailored to the cartoon tank models and the dark, gold-accented menus. No third-party recordings, sample libraries, voice, or paid generation service were used. These assets follow the project's existing licensing status; this package does not introduce a new license.

## Sound palette

- Eight cannon signatures: a light pop for Scout/Sprinter, a sharp ping for Needle, heavier thumps for Bulldog/Mortar/Command. Duelist plays its sound for each actual barrel discharge.
- Three spring-metal ricochets and three rounded tank explosions, selected without immediate repeats.
- Mine placement clunk, one arming chirp, and a deeper detonation.
- A quiet reload latch and a seamless motor/tread loop that follows movement and turning. The camera's current tank supplies the motor while spectating.
- Gentle menu focus, confirmation, back, tank selection, pause and resume sounds; short launch, victory, defeat and player-down phrases.

Two original 32-bar music loops share the toybox palette: **Rollout Club** (104 BPM, 74 seconds) plays on the main menu and tank selection; **Tin Track Rally** (128 BPM, 60 seconds) plays during matches and spectating. Plucked notes, mallets, warm keys and bass give way to a more energetic reed lead and drums in battle. Each track has a quieter middle section and a final variation.

## Runtime

`scripts/game_audio.gd` preloads all 29 sounds so they remain dependencies in scene-based exports. It bounds playback at 16 spatial effects and six menu voices, plus one motor loop. World effects use 3D attenuation; the engine is intentionally quiet. The Master bus includes peak protection. The existing Volume slider controls every bus, including an audible slider preview.

Music uses two additional players for a 1.2-second crossfade. It continues through related menus without restarting, softens to 30% during pause/settings/results, and briefly ducks under round stingers. It uses the same Volume slider. The effects and engine buses have been raised by 5 dB from the original sound pass, and menu effects by 4 dB; the Music bus is set to -4 dB.

Pause and settings opened from pause suspend world voices. Menu sounds remain active. Results allow the last explosion to finish; returning to the main menu clears the arena voices. A failed fire/mine attempt makes no sound.

The source WAVs are mono, 44.1 kHz, 16-bit PCM, totaling about 1.84 MB. Godot's imports may compress them. Loop bounds use sample frames rather than compressed byte count. No server, streaming service, or network request is needed to play them.

The two music masters are stereo PCM16 at 32 kHz. Their Godot QOA imports total about 3.3 MB. Note tails and room reflections wrap across the complete loop boundary rather than fading out each time.

## Rebuild and check

Run `python3 tools/build_audio.py` from the project folder. This overwrites the 29 generated WAVs, their manifest, and the listening reel with deterministic outputs. Hand edits to those generated files should be saved separately before rebuilding.

`manifest.json` records each asset's description, duration, levels and SHA-256, as well as the generator digest and provenance. The runtime test is `tests/audio.gd`; it exercises the actual game events, menu/pause/volume flow, the motor, voice limits, and records the mixed output.

Music has its own generator, `tools/build_music.py` (Python with NumPy), and provenance manifest, `music/manifest.json`. Rebuilding overwrites the two music masters and their 33-second preview. `tests/music.gd` checks the real scene transitions, pause levels, master mute, native mixed output, and playback across both loop boundaries. Its review files live in `art-review/music-v1/`.

The listening reel and validation reports are in `art-review/audio-v1/`. Native CoreAudio playback has been checked through an actual mixer capture. Browser/iPad/mobile-device playback has not yet been tested; the files use Godot-native audio streams and require no platform-specific audio code.
