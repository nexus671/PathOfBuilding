"""Compile deterministic Harvest enchantments from pinned client/game exports."""
# cspell:ignore executescript repoe
import hashlib
import json
import sqlite3
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
CLIENT = "9a435a565d5b2e180714724e38e0161d0c39842a"
REPOE = "ae6d85a5c36857e08819852ab8732239294aba59"
hashes = {}


def fetch(repo, commit, path):
    url = f"https://raw.githubusercontent.com/{repo}/{commit}/{path}"
    with urlopen(url, timeout=60) as response:
        raw = response.read()
    hashes[url] = hashlib.sha256(raw).hexdigest()
    return raw


db = sqlite3.connect(":memory:")
db.row_factory = sqlite3.Row
blocked = {sqlite3.SQLITE_ATTACH, sqlite3.SQLITE_DETACH, sqlite3.SQLITE_PRAGMA,
           sqlite3.SQLITE_FUNCTION, sqlite3.SQLITE_CREATE_VTABLE}
db.set_authorizer(lambda operation, *_: sqlite3.SQLITE_DENY if operation in blocked else sqlite3.SQLITE_OK)
for folder, prefix in [("base/client/", ""), ("updates/client/", "2026_11_09_162805_")]:
    raw = fetch("LocalExile/LocalExile", CLIENT, "sql/" + folder + prefix + "HarvestCraftOptions.sql")
    assert "3.29.3c" in raw.decode().splitlines()[0]
    db.executescript(raw.decode())
mods = json.loads(fetch("repoe-fork/repoe-fork.github.io", REPOE, "data/mods.json"))
bases = json.loads(fetch("repoe-fork/repoe-fork.github.io", REPOE, "data/base_items.json"))
crafts = {}
classes = set()
for row in db.execute("SELECT * FROM HarvestCraftOptions WHERE IsEnchant=1 ORDER BY Id"):
    assert row["Command"] == "add_enchant_to_class"
    before, mod_id = row["Parameters"].split(" ENCHANTS ")
    allowed = [value.replace("_", " ") for value in before.split()]
    classes.update(allowed)
    mod = mods[mod_id]
    assert mod["text"] and row["SacredCost"] == 0
    crafts[row["Id"]] = {"modId": mod_id, "classes": allowed, "lines": mod["text"].splitlines(),
                         "lifeforceType": row["LifeforceType"], "cost": row["LifeforceCost"]}
assert len(crafts) == 14
base_classes = {}
ambiguous = set()
for base in bases.values():
    if base["item_class"] not in classes:
        continue
    previous = base_classes.setdefault(base["name"], base["item_class"])
    if previous != base["item_class"]:
        ambiguous.add(base["name"])
for name in ambiguous:
    del base_classes[name]
result = {"_comment": "Generated GGG game data. cspell:disable", "patch": "3.29.3.6",
          "source": {"clientCommit": CLIENT, "repoeCommit": REPOE, "hashes": hashes},
          "crafts": crafts, "baseClasses": base_classes}
(ROOT / "src/Data/Crafting/HarvestEnchants.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Compiled {len(crafts)} Harvest enchantments for {len(base_classes)} bases")
