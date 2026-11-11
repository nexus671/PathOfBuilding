"""Compile GGG's client crafting tables into the native Allflame catalog."""
# cspell:ignore executescript
import hashlib
import json
import sqlite3
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "9a435a565d5b2e180714724e38e0161d0c39842a"
SOURCE = "LocalExile/LocalExile"
TABLES = ["BaseItemTypes", "CurrencyItems", "ItemClasses", "DeepwaterCraftingCurrencies",
          "DeepwaterCraftingClasses", "DeepwaterBalancePerLevel"]
db = sqlite3.connect(":memory:")
db.row_factory = sqlite3.Row
# Source files contain game-data INSERT statements. Keep all evaluation in memory.
blocked = {sqlite3.SQLITE_ATTACH, sqlite3.SQLITE_DETACH, sqlite3.SQLITE_PRAGMA,
           sqlite3.SQLITE_FUNCTION, sqlite3.SQLITE_CREATE_VTABLE}
db.set_authorizer(lambda operation, *_: sqlite3.SQLITE_DENY if operation in blocked else sqlite3.SQLITE_OK)
hashes = {}
for table in TABLES:
    for folder, prefix in [("base/client/", ""), ("updates/client/", "2026_11_09_162805_")]:
        path = "sql/" + folder + prefix + table + ".sql"
        with urlopen(f"https://raw.githubusercontent.com/{SOURCE}/{COMMIT}/{path}", timeout=30) as response:
            raw = response.read()
        hashes[path] = hashlib.sha256(raw).hexdigest()
        assert "3.29.3c" in raw.decode().splitlines()[0], "Unexpected client build"
        db.executescript(raw.decode())

classes = {row["Id"]: {"costPercent": row["__col1"], "levelScaling": bool(row["__col2"])}
           for row in db.execute("SELECT d.*, c.Id FROM DeepwaterCraftingClasses d JOIN ItemClasses c ON d.ItemClass=c._row")}
levels = {str(row["__col0"]): row["__col1"] for row in db.execute("SELECT * FROM DeepwaterBalancePerLevel")}
bases = {}
ambiguous = set()
for row in db.execute("SELECT b.Name,c.Id FROM BaseItemTypes b JOIN ItemClasses c ON b.ItemClassesKey=c._row"):
    if row["Id"] not in classes:
        continue
    if row["Name"] in bases and bases[row["Name"]] != row["Id"]:
        ambiguous.add(row["Name"])
    bases[row["Name"]] = row["Id"]
for name in ambiguous:
    del bases[name]
currencies = {}
for row in db.execute("SELECT d.*,b.Id,b.Name FROM DeepwaterCraftingCurrencies d JOIN CurrencyItems c ON d.Currency=c._row JOIN BaseItemTypes b ON c.BaseItemTypesKey=b._row"):
    assert 0 <= row["__col1"] <= 2
    assert 1 <= row["__col2"] <= row["__col3"] <= 4
    assert 0 <= row["__col12"] <= row["__col13"] <= 100
    assert row["Cost"] >= 0
    entry = currencies.setdefault(row["Id"], {"name": row["Name"], "tiers": []})
    entry["tiers"].append({"tier": row["__col1"], "minOutcomes": row["__col2"], "outcomes": row["__col3"],
                           "baseCost": row["Cost"], "gainMin": row["__col12"], "gainMax": row["__col13"]})
assert sum(len(entry["tiers"]) for entry in currencies.values()) == 293
result = {"_comment": "GGG client game data. cspell:disable", "patch": "3.29.3c",
          "source": {"repo": SOURCE, "commit": COMMIT, "hashes": hashes},
          "classes": classes, "levels": levels, "baseClasses": bases, "currencies": currencies}
(ROOT / "src" / "Data" / "Crafting" / "Allflame.json").write_text(json.dumps(result, separators=(",", ":"), ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Compiled {len(currencies)} Allflame currencies and {len(classes)} classes")
