# Startrail Maze

Separate top-down 3D maze game for Godot/FRT 4.1.3. Three deterministic gardens:
Clover Court, Lavender Lanes, Sunset Garden. Walk with the D-pad, collect three
blue keys to unlock the arch, and optionally find twelve stars. No timer, lives
or enemies. A hops; after reaching the unlocked exit, A opens the next garden.
Hold B for an overview, Start pauses, Select saves and quits. Hopping is cosmetic:
it does not bypass maze walls. After the third garden the sequence loops.

Uses the measured Pocket Meadow renderer/launcher foundation, but this game's
handheld performance is [Unverified] until separately measured. Native 720x720,
60 FPS cap, batched static geometry. All models and sounds generated in code.

Build: sh build.sh /path/to/Godot_v4.1.3-stable_linux.x86_64 /path/to/output
PC self-test verifies each maze's exit route and collectible positions, wall
blocking, duplicate pickups, key requirements, saved progress, winning and pause.
Evidence: evidence/pc-self-test.log. Benchmark mode follows a maze route for
23 seconds, measuring wall-clock frame intervals after a three-second warmup.
Benchmark saves are isolated and normal progress is not loaded or written.

Deploy files to /storage/roms/ports/startrailmaze/. Runtime shared from
/storage/roms/ports/backyardbash/frt/. Install Startrail Maze.sh into ports_scripts
only after hardware checks; never edit gamelist.xml. Test detached using
systemd-run --unit=startrail-maze-test --quiet sh /storage/roms/ports/startrailmaze/test-maze.sh
The test restores EmulationStation and uses separate saves. Production runner
does not manage the frontend. Normal saves: startrailmaze/savedata/.

Status: PC import/self-test/export passed. Handheld SSH timed out during initial
work. [Unverified] Handheld performance, visual appearance and physical input.
