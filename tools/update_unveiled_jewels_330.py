"""Extract 3.30 unveiled jewel modifiers from a pinned local client export."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "a6814fdd00755eca4208b2d5bae7877795e5c91a2d0935daa6748b49f26ec0ce"
OUTPUT = ROOT / "src/Data/Crafting/3.30-unveiled-jewels.json"


def build(path):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Unexpected client modifier export; inspect and pin it before updating")
    current = json.loads(raw)
    previous = json.loads((ROOT / "src/Data/Crafting/3.29.json").read_text(encoding="utf-8"))["mods"]
    mods = {}
    for key in sorted(current.keys() - previous.keys()):
        mod = current[key]
        if mod.get("domain") != "unveiled":
            continue
        if len(mod["groups"]) != 1 or not mod.get("text"):
            raise ValueError(f"Unexpected unveiled modifier: {key}")
        text = re.sub(r"\[([^\[\]]+)\]", lambda m: m.group(1).split("|")[-1], mod["text"])
        mods[key] = {"name": mod["name"], "type": mod["generation_type"], "group": mod["groups"][0],
                     "level": mod["required_level"], "text": text.splitlines(), "tags": mod["implicit_tags"],
                     "weights": mod["spawn_weights"], "stats": mod["stats"]}
    if len(mods) != 53:
        raise ValueError(f"Expected 53 unveiled jewel modifiers, found {len(mods)}")
    return {"schemaVersion": 1, "clientVersion": "3.30.0.1.4", "sourceSha256": SOURCE_SHA256, "mods": mods}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mods", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = json.dumps(build(args.mods), ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    if args.check:
        if OUTPUT.read_text(encoding="utf-8") != data:
            raise SystemExit("Unveiled jewel data does not match the pinned source")
    else:
        OUTPUT.write_text(data, encoding="utf-8", newline="\n")
    print(f"Verified {len(json.loads(data)['mods'])} unveiled jewel modifiers")


if __name__ == "__main__":
    main()
