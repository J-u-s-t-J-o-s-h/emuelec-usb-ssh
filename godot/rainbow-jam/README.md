# Rainbow Jam
A musical playground for FRT/Godot4.1.3. Face buttons play piano-like C/E/G/A,
D-pad plays plucked-string C/E/G/A, L1 kick, R1 snare, L2 hi-hat, R2 clap.
Start cycles three musical keys; Select quits. Press again to retrigger; holding
does not auto-repeat. Up to16 overlapping voices, with deterministic voice stealing.
Twelve colored pads bounce and brighten; notes create orbiting rings and sparks.
Effects are bounded to12 simultaneous bursts; no full-screen flashing.

Original synthesized sounds generated offline by generate-sounds.py (Python3,
standard library), not recordings of acoustic instruments. See audio-generation.json
for PCM peak, rate and endpoints. All samples start/end at zero. Peak24000/32768
and -25dB per voice bound worst-case16-voice sum below1.0 before device output.
[Unverified] Perceived loudness, timbre, physical latency and speaker quality.

Build: sh build.sh /path/to/Godot_v4.1.3-stable_linux.x86_64 /path/to/output
600x600 rendering upscaled to720, target60 FPS. [Unverified] Hardware benchmark pending.
Self-test checks all12 sound/visual triggers, hold suppression, voice/effect bounds
and key cycling. controls-check.gd verifies injected input, simultaneous playback
and quit. Benchmark stresses six notes every0.1s for23seconds, sampling after3s.

Install to /storage/roms/ports/rainbowjam/; runtime shared from backyardbash/frt/.
Production runner run-jam.sh; jam.gptk mappings. Test detached with systemd-run:
 systemd-run --unit=rainbow-jam-test --quiet sh /storage/roms/ports/rainbowjam/test-jam.sh
Tests bound runtime and restore EmulationStation. No gamelist.xml edits.
Install Rainbow Jam.sh in ports_scripts only after hardware validation.
