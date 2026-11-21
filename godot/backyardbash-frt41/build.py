#!/usr/bin/env python3
"""Create a new patched copy and export using the official Godot 4.1.3 Linux editor."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("original", type=Path)
parser.add_argument("destination", type=Path)
parser.add_argument("editor", type=Path)
args = parser.parse_args()
here = Path(__file__).resolve().parent
original = args.original.resolve()
destination = args.destination.resolve()
editor = args.editor.resolve()
if destination.exists() or original == destination or original in destination.parents:
    parser.error("Destination must be new and outside the original project.")
if not shutil.which("patch"):
    parser.error("Install the patch utility in WSL/Linux first.")
for relative, expected in json.loads((here / "source-sha256.json").read_text()).items():
    actual = hashlib.sha256((original / relative).read_bytes()).hexdigest()
    if actual != expected:
        parser.error("Original source fingerprint mismatch: " + relative)
version = subprocess.check_output([str(editor), "--version"], text=True).strip()
if version != "4.1.3.stable.official.f06b6836a":
    parser.error("Wrong editor version: " + version)
destination.mkdir(parents=True)
project = destination / "source"
shutil.copytree(original, project, ignore=shutil.ignore_patterns(".godot"))
# Windows source has CRLF; the portable patch uses LF.
for p in project.rglob("*"):
    if p.suffix in (".gd", ".godot", ".cfg", ".tscn", ".tres"):
        p.write_text(p.read_text(), newline="\n")
subprocess.run(["patch", "--batch", "--forward", "-p1", "-i", str(here / "port.patch")],
               cwd=project, check=True)
logs = destination / "logs"
logs.mkdir()
def run(label, options, allowed_errors=(), required_marker=None):
    command = [str(editor), "--headless", "--path", str(project)] + options
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=120)
    (logs / (label + ".log")).write_text(result.stdout)
    print(label, "exit", result.returncode)
    errors = [line for line in result.stdout.splitlines() if line.startswith("ERROR:")]
    unexpected = [line for line in errors if line not in allowed_errors]
    if errors:
        print("Recorded diagnostics:", *sorted(set(errors)), sep="\n")
    if (result.returncode or "SCRIPT ERROR:" in result.stdout or unexpected
            or (required_marker and required_marker not in result.stdout)):
        raise SystemExit("Build failed: inspect " + str(logs / (label + ".log")))
run("import", ["--editor", "--quit"])
run("bake-audio", ["--script", "res://tests/bake_audio.gd", "--", "--bake-audio"])
cleanup_errors = (
    "ERROR: Resources still in use at exit (run with --verbose for details).",
    "ERROR: Pages in use exist at exit in PagedAllocator: N7Variant5Pools12BucketMediumE",
)
run("export", ["--export-pack", "Linux", str(destination / "game.pck")],
    cleanup_errors, "savepack: end")
run("pack-smoke", ["--main-pack", str(destination / "game.pck"), "--",
    "--smoke-test", "--smoke-players=1"], cleanup_errors + (
    'ERROR: Condition "!m" is true. Returning: 0',), "SMOKE_PASS")
digest = hashlib.sha256((destination / "game.pck").read_bytes()).hexdigest()
(destination / "game.pck.sha256").write_text(digest + "  game.pck\n")
print("Exported", destination / "game.pck", digest)
