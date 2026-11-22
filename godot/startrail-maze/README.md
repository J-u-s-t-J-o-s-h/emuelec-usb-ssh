# Startrail Maze

Separate top-down 3D maze game for Godot/FRT 4.1.3. Three deterministic gardens:
Clover Court, Lavender Lanes, Sunset Garden. Walk with the D-pad, collect three
blue keys to unlock the arch, and optionally find twelve stars. No timer, lives
or enemies. A hops; after reaching the unlocked exit, A opens the next garden.
Hold B for an overview, Start pauses, Select saves and quits. Hopping is cosmetic:
it does not bypass maze walls. After the third garden the sequence loops.

All models and sounds generated in code. Static scenery, avatar, keys and exit
use batched meshes. HUD text changes only when state changes.

## Build and tests
Build: sh build.sh /path/to/Godot_v4.1.3-stable_linux.x86_64 /path/to/output
PC self-test verifies maze exit routes and collectible positions, wall blocking,
duplicate pickups, key requirements, saved progress, winning and pause.
Rendered controls-check.gd tests injected keyboard input, overview, collision,
next-maze entrance and Escape quit. It does not establish physical pad behavior.

Deploy to /storage/roms/ports/startrailmaze/. Shared runtime:
 /storage/roms/ports/backyardbash/frt/
Run bounded tests detached:
 systemd-run --unit=startrail-maze-test --quiet sh /storage/roms/ports/startrailmaze/test-maze.sh
test-controls.sh checks input; test-suite.sh benchmarks all three gardens and
overview. Each restores EmulationStation and uses test-savedata/.
Install Startrail Maze.sh in ports_scripts after validation; never edit gamelist.xml.
Production saves: startrailmaze/savedata/. Production runner leaves frontend
lifecycle management to Ports.

Benchmark runs 23 seconds, sampling wall-clock frame intervals after a
three-second warmup. --benchmark-stage=0/1/2 selects garden; --benchmark-map
forces overview. Benchmark skips loading/writing production progress.

## Measured optimization history
Native 720 baseline: 54.39 FPS (device-baseline.log).
HUD caching alone: 53.55 FPS (device-hud-cache.log).
Key/gate batching: 54.62 FPS (device-key-batching.log).
Reduced overlapping surfaces + avatar batching: 56.80 FPS (device-surfaces.log).
These runs do not establish a controlled causal comparison; all miss the target.
Current candidate uses 600x600 internal rendering scaled to the 720x720 screen;
HUD scales with it. [Unverified] Candidate performance pending hardware test.
Candidate SHA256: 03aaab070783c697b41a3a8d4bc8a6584fb8e4cb9c69e0168767ad00a0da0c69.

## Known limits
[Unverified] Physical input, audio, perceived smoothness and full user playthrough.
An earlier timed headless input test failed walking; cause unverified. Rendered
PC controls tests passed. Headless logic tests pass but shutdown emits dummy
renderer mesh errors; controls harness emits an ObjectDB leak warning.
Initial WSL visual test lacked ALSA; later PC tests use Dummy audio.
Screenshots/evidence explicitly marked PC must not be treated as handheld evidence.
