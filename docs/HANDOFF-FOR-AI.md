# Handoff notes for another AI assistant

Read `README.md` first, then `docs/findings.md`. Facts there are labelled Verified / Inferred / Unexplained - keep that discipline.

Ground rules that worked (and why):
1. **The card is the only fallback channel.** If SSH is down, every change costs a physical card swap. Batch evidence-gathering and fixes into one trip.
2. **Never edit `ports_scripts/gamelist.xml`, never add new files to `ports_scripts/`.** One boot failed after doing both (cause undetermined). Put payloads in `/storage/roms/.usbssh/` instead; replacing an existing launcher is fine.
3. **Confirm the volume label `EEROMS` before writing to the card from Windows.** `install-to-card.ps1` enforces it.
4. **Handheld scripts must be LF.** Check for CR bytes before copying; `.gitattributes` enforces it.
5. **Write each diagnostic section then `sync`.** A crash or power-off still leaves partial evidence on the card.
6. **Update the SSH server via a test instance on port 2222 first** (`handheld/update-*.sh`), keep `.prev`, then swap. Existing SSH sessions survive killing the listener.
7. **Keep the charger on the charge-only port** during long work; `zed_gadget.service` powers off at <= 3.40 V when not charging.
8. Reach the handheld with `ssh emuelec` (needs `windows/ssh-config.txt` in the user's SSH config). Feed scripts with `ssh emuelec sh -s < script.sh` to avoid quoting problems.

Open work (next): the Godot game. Current state and a ready-to-paste prompt are in `docs/HANDOFF-PROMPT.md`;
technical detail in `godot/README.md`. Short version: the FRT 4.1.3 runtime renders at ~52 FPS and input works via `gptokeyb`;
the game must be downgraded from Godot 4.7 to 4.1 (on a copy of the project) and given a new launcher.
