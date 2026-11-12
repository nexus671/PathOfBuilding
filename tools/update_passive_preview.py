"""Generate the opt-in 3.30 passive preview from a pinned official GGG export."""
import concurrent.futures
import hashlib
import importlib.util
import json
import re
import tempfile
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "550fb34ae7fca9ec4d760a2ac845bb2ba1032ec3"
SOURCE = f"https://raw.githubusercontent.com/grindinggear/skilltree-export/{COMMIT}/data.json"
DESTINATION = ROOT / "src/TreeData/3_30_preview"


def lua(value, depth=0):
    indent = "\t" * depth
    if isinstance(value, dict):
        entries = value.items()
    elif isinstance(value, list):
        entries = enumerate(value, 1)
    elif value is None:
        return "nil"
    elif isinstance(value, bool):
        return "true" if value else "false"
    else:
        return json.dumps(value, ensure_ascii=False)
    lines = []
    for key, entry in entries:
        if isinstance(key, str) and re.fullmatch(r"[0-9]+", key):
            key = int(key)
        lines.append(indent + "\t[" + json.dumps(key, ensure_ascii=False) + "] = " + lua(entry, depth + 1) + ",")
    return "{\n" + "\n".join(lines) + "\n" + indent + "}"


def main():
    with urlopen(SOURCE, timeout=30) as response:
        raw = response.read()
    original = json.loads(raw)
    assert original["tree"] == "Default"
    module_spec = importlib.util.spec_from_file_location("fix_ascendancy_positions", ROOT / "fix_ascendancy_positions.py")
    fixer = importlib.util.module_from_spec(module_spec)
    import sys
    sys.modules[module_spec.name] = fixer
    module_spec.loader.exec_module(fixer)
    with tempfile.TemporaryDirectory(prefix="pob-passive-preview-") as directory:
        path = Path(directory) / "data.json"
        path.write_bytes(raw)
        fixer.fix_ascendancy_positions(path)
        data = json.loads(path.read_text(encoding="utf-8"))
        sprites = json.loads(path.with_name("sprites.json").read_text(encoding="utf-8"))
    DESTINATION.mkdir(parents=True, exist_ok=True)
    header = "-- Generated official GGG preview data. cspell:disable\nreturn "
    (DESTINATION / "tree.lua").write_text(header + lua(data) + "\n", encoding="utf-8")
    (DESTINATION / "sprites.lua").write_text(header + lua(sprites) + "\n", encoding="utf-8")
    names = sorted({Path(urlsplit(sheet["filename"]).path).name for sheet in sprites["sprites"].values()})

    def asset(name):
        assert re.fullmatch(r"[a-zA-Z0-9_.-]+", name)
        source = f"https://raw.githubusercontent.com/grindinggear/skilltree-export/{COMMIT}/assets/{name}"
        with urlopen(source, timeout=60) as response:
            content = response.read()
        (DESTINATION / name).write_bytes(content)
        return name, {"source": source, "sha256": hashlib.sha256(content).hexdigest()}

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        assets = dict(pool.map(asset, names))
    provenance = {"_comment": "Generated official GGG data. cspell:disable", "preview": True,
                  "source": SOURCE, "commit": COMMIT, "sha256": hashlib.sha256(raw).hexdigest(),
                  "preprocessor": "fix_ascendancy_positions.py", "assets": assets}
    (DESTINATION / "source.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    print(f"3.30 preview: {len(data['nodes'])} nodes, {len(assets)} sprite sheets, source {provenance['sha256']}")


if __name__ == "__main__":
    main()
