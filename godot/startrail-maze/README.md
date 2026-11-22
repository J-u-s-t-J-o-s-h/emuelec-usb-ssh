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
Final build uses **600x600 internal rendering**, upscaled to the 720x720 screen,
with complete plain-text HUD on dark panels. Whole scene and HUD are scaled.
Shadowed text was removed. The earlier 59.99 result with clipped HUD is superseded.

## Final handheld validation

| Mode | FPS | Median ms | p95 ms | Worst ms |
|---|---:|---:|---:|---:|
| Clover Court | 60.00 | 16.67 | 16.73 | 16.98 |
| Lavender Lanes | 59.99 | 16.67 | 16.73 | 16.90 |
| Sunset Garden | 59.99 | 16.67 | 16.73 | 16.90 |
| Overview | 59.99 | 16.67 | 16.73 | 16.87 |

Evidence: evidence/benchmark-stage-0.log through stage-2.log, benchmark-map.log,
device-controls.log and deployment.txt. Final screenshot: evidence/device-preview.png.
All bounded wrappers exited zero and restored EmulationStation.
Controls tests passed injected-key walking, hop, pause, overview, wall blocking,
locked/unlocked exit, next-maze entrance and quit. They are not physical-pad tests.
Ports launcher installed separately; gamelist.xml checksum remained unchanged.
Final pack SHA256:
74b53e5e8545f8e0da97850b5a5df7160e004a283ac9d91dc4fd5cf66fc4e59a.

Each benchmark samples about 20 seconds after warmup, follows only one route, and
skips save writes. Frame intervals are process-callback timing, not display scanout.
These results are not a promise of identical performance on every route.
See evidence/validation-notes.txt for experiment history and measurement limits.

## Known limits
[Unverified] Physical input, audio, perceived smoothness and full user playthrough.
An earlier timed headless input test failed walking; cause unverified. Rendered
PC controls tests passed. Headless logic tests pass but shutdown emits dummy
renderer mesh errors; controls harness emits an ObjectDB leak warning.
Initial WSL visual test lacked ALSA; later PC tests use Dummy audio.
Screenshots/evidence explicitly marked PC must not be treated as handheld evidence.
