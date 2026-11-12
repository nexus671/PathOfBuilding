"""Exercise native controls and audit rendered frames without opening a window."""
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path

from render_headless_ui import render

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default="luajit", help="LuaJIT executable; defaults to PATH")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/headless-ui")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="run-", dir=args.output.resolve()))
    frames = directory / "frames"
    frames.mkdir()
    environment = dict(os.environ, LUA_PATH="../runtime/lua/?.lua;../runtime/lua/?/init.lua;;")
    if os.name == "nt":
        environment["LUA_CPATH"] = str(ROOT / "runtime/?.dll") + ";;"
        environment["PATH"] = str(ROOT / "runtime") + os.pathsep + environment["PATH"]
    result = subprocess.run([args.lua, "../tools/test_headless_ui.lua", str(frames)], cwd=ROOT / "src",
                            env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (directory / "controls.log").write_text(result.stdout)
    assert result.returncode == 0, result.stdout
    paths = sorted(frames.glob("*.json"))
    assert len(paths) == 94, f"Expected ninety-four UI frames, found {len(paths)}"
    failures = []
    for path in paths:
        image, audit = render(json.loads(path.read_text()))
        image.save(directory / (path.stem + ".png"))
        (directory / (path.stem + ".audit.json")).write_text(json.dumps(audit, indent=2))
        if any(audit[key] for key in ("lowContrast", "horizontalClipping", "controlClipping", "controlOverlaps")):
            failures.append({"frame": path.name, "audit": audit})
    negative = json.loads((directory / "expected-audit-failures.json").read_text())
    image, audit = render(negative)
    image.save(directory / "expected-audit-failures.png")
    assert audit["lowContrast"] and audit["horizontalClipping"] and audit["controlOverlaps"], "UI audits failed to detect the deliberate bad fixture"
    try:
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
        dirty = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).splitlines()
    except (FileNotFoundError, subprocess.CalledProcessError):
        revision = environment.get("GITHUB_SHA")
        dirty = None
    sources = list((ROOT / "src/Classes").glob("*.lua")) + list((ROOT / "src/Modules").glob("*.lua"))
    sources += list((ROOT / "runtime/SimpleGraphic/Fonts").glob("*"))
    sources += list((ROOT / "src/Assets/Crafting").rglob("*"))
    sources += list((ROOT / "src/Assets/Atlas").rglob("*"))
    sources += [ROOT / "src/Data/Global.lua", Path(__file__), ROOT / "tools/render_headless_ui.py", ROOT / "tools/test_headless_ui.lua"]
    hashes = {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(sources) if path.is_file()}
    (directory / "report.json").write_text(json.dumps({"revision": revision, "workingTreeChanges": dirty,
        "sourceHashes": hashes, "frames": len(paths), "failures": failures, "auditSelfTest": "passed",
        "limitations": negative["limitations"]}, indent=2))
    print(f"Headless UI: {len(paths)} frames, {len(failures)} failures. Artifacts: {directory}")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
