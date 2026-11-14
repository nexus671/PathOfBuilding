"""Check whether an immutable RePoE revision has actually exported new data."""
# cspell:ignore repoe
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

REPO = "repoe-fork/repoe-fork.github.io"
ROOT = Path(__file__).resolve().parents[1]
FILES = ("mods.json", "fossils.json", "base_items.json", "crafting_bench_options.json")


def fetch(url):
    request = Request(url, headers={"User-Agent": "PathOfBuilding-AI-Edition"})
    with urlopen(request, timeout=90) as response:
        return response.read()


def version(raw):
    value = raw.decode("utf-8-sig").strip()
    if not value or not all(part.isdigit() for part in value.split(".")):
        raise ValueError("Invalid exported game-data version")
    return value


def require_exported(expected, actual):
    if expected != actual:
        raise ValueError(f"Expected exported data {expected}, but the source reports {actual}; wait for the export or select the correct patch")


def require_changed_export(expected, pinned, old_hashes, new_hashes, allow_identical=False):
    if any(name not in old_hashes or name not in new_hashes for name in FILES):
        raise ValueError("All crafting source hashes are required")
    if expected != pinned and not allow_identical and all(old_hashes[name] == new_hashes[name] for name in FILES):
        raise ValueError("All crafting exports match the previous patch; review the sources before using --allow-identical-export")


def require_supported_granted_effects(previous, exported):
    """Reject a changed support-level representation until the importer handles it."""
    affected = []
    for identifier in previous.keys() & exported.keys():
        current = exported[identifier]
        if not current.get("grants_effects"):
            continue
        old_stats = {stat["id"]: stat for stat in previous[identifier]["stats"]}
        for stat in current["stats"]:
            old = old_stats.get(stat["id"])
            if (old and stat["id"].startswith("local_display_")
                    and (old["min"], old["max"]) != (0, 0)
                    and (stat["min"], stat["max"]) == (0, 0)):
                affected.append(identifier)
                break
    if affected:
        raise ValueError(f"{len(affected)} modifiers have zeroed display values and granted effects; update the importer before using this export (example: {sorted(affected)[0]})")


def assess(pinned, detected, exported, old_hashes, new_hashes=None):
    if detected != exported:
        return {"status": "export_pending", "changedFiles": []}
    if new_hashes is None or any(name not in new_hashes or name not in old_hashes for name in FILES):
        raise ValueError("All crafting source hashes are required")
    changed = [name for name in FILES if old_hashes[name] != new_hashes[name]]
    if changed:
        status = "review_required"
    elif exported == pinned:
        status = "unchanged"
    else:
        status = "version_only"
    return {"status": status, "changedFiles": changed}


def main():
    pinned = json.loads((ROOT / "src/Data/Crafting/3.29.json").read_text(encoding="utf-8"))
    revision = json.loads(fetch(f"https://api.github.com/repos/{REPO}/commits/master"))["sha"]
    base = f"https://raw.githubusercontent.com/{REPO}/{revision}/"
    detected = version(fetch(base + "version.txt"))
    exported = version(fetch(base + "exported-version.txt"))
    hashes = None
    if detected == exported:
        hashes = {name: hashlib.sha256(fetch(base + "data/" + name)).hexdigest() for name in FILES}
    result = assess(pinned["patch"], detected, exported, pinned["hashes"], hashes)
    result.update({"revision": revision, "pinned": pinned["patch"], "detected": detected, "exported": exported})
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
