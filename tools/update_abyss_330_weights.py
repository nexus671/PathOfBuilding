"""Extract the verified 3.30 Abyss weight changes from a local client export."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "a6814fdd00755eca4208b2d5bae7877795e5c91a2d0935daa6748b49f26ec0ce"
OUTPUT = ROOT / "src/Data/Crafting/3.30-abyss-weights.json"


def build(path):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Unexpected client modifier export; inspect and pin it before updating")
    current = json.loads(raw)
    previous = json.loads((ROOT / "src/Data/Crafting/3.29.json").read_text(encoding="utf-8"))["mods"]
    updates = {}
    for key in sorted(previous.keys() & current.keys()):
        old, new = previous[key], current[key]
        if old.get("domain") != "abyss_jewel" or old.get("spawn_weights") == new.get("spawn_weights"):
            continue
        updates[key] = new["spawn_weights"]
    if len(updates) != 446:
        raise ValueError(f"Expected 446 Abyss weight changes, found {len(updates)}")
    return {"schemaVersion": 1, "clientVersion": "3.30.0.1.4", "sourceSha256": SOURCE_SHA256, "weights": updates}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mods", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = json.dumps(build(args.mods), ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    if args.check:
        if OUTPUT.read_text(encoding="utf-8") != data:
            raise SystemExit("Abyss weights do not match the pinned source")
    else:
        OUTPUT.write_text(data, encoding="utf-8", newline="\n")
    print(f"Verified {len(json.loads(data)['weights'])} Abyss weight changes")


if __name__ == "__main__":
    main()
