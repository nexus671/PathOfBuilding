"""Compare a local RePoE modifier export with the current crafting supplement.

This reports differences only; matching identifiers do not establish that an
export or its schema is correct for a game version.
"""
import argparse
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("groups", "stats", "domain", "implicit_tags", "adds_tags",
          "generation_weights", "spawn_weights", "is_essence_only",
          "required_level", "generation_type")


def compare(previous, exported):
    old = previous["mods"]
    shared = old.keys() & exported.keys()
    changed = {field: sorted(key for key in shared
                             if old[key].get(field) != exported[key].get(field))
               for field in FIELDS}
    return {
        "previous_patch": previous["patch"],
        "previous_count": len(old),
        "export_count": len(exported),
        "shared_count": len(shared),
        "missing_ids": sorted(old.keys() - exported.keys()),
        "additional_count_by_domain": dict(sorted(Counter(
            mod.get("domain", "<missing>") for key, mod in exported.items()
            if key not in old).items())),
        "changed_ids_by_field": changed,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mods", type=Path, help="Path to the candidate mods.json")
    parser.add_argument("--previous", type=Path, default=ROOT / "src/Data/Crafting/3.29.json")
    args = parser.parse_args()
    with args.previous.open(encoding="utf-8") as source:
        previous = json.load(source)
    with args.mods.open(encoding="utf-8") as source:
        exported = json.load(source)
    print(json.dumps(compare(previous, exported), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
