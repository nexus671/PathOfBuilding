"""Rebuild supplemental crafting data from immutable RePoE game exports."""
# cspell:ignore repoe
import hashlib
import argparse
import json
import re
from pathlib import Path
from urllib.request import urlopen
from crafting_data_status import require_changed_export, require_exported, version

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "repoe-fork/repoe-fork.github.io"
COMMIT = "ae6d85a5c36857e08819852ab8732239294aba59"
PATCH = "3.29.3.6"
FILES = ["mods.json", "fossils.json", "base_items.json", "crafting_bench_options.json"]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--allow-identical-export", action="store_true", help="Allow a reviewed new patch whose crafting source files are unchanged")
args = parser.parse_args()
with urlopen(f"https://raw.githubusercontent.com/{REPOSITORY}/{COMMIT}/exported-version.txt", timeout=60) as response:
    require_exported(PATCH, version(response.read()))
raw = {}
for name in FILES:
    with urlopen(f"https://raw.githubusercontent.com/{REPOSITORY}/{COMMIT}/data/{name}", timeout=60) as response:
        raw[name] = response.read()
destination = ROOT / "src" / "Data" / "Crafting" / "3.29.json"
if destination.exists():
    previous = json.loads(destination.read_text(encoding="utf-8"))
    require_changed_export(PATCH, previous["patch"], previous["hashes"],
                           {name: hashlib.sha256(content).hexdigest() for name, content in raw.items()},
                           args.allow_identical_export)
mods, fossils, bases, bench = (json.loads(raw[name]) for name in FILES)
identifiers = set()
for source in (ROOT / "src" / "Data").glob("*.lua"):
    if source.name.startswith("Mod") or source.name in ["BeastCraft.lua", "Essence.lua"]:
        identifiers.update(re.findall(r'\["([^"]+)"\]\s*=', source.read_text(encoding="utf-8-sig")))
fields = ["groups", "stats", "domain", "implicit_tags", "adds_tags", "generation_weights",
          "spawn_weights", "is_essence_only", "required_level", "generation_type"]
generation = {"prefix", "suffix", "corrupted", "searing_exarch_implicit", "eater_of_worlds_implicit", "synthesis_a"}
ducat_mods = {key: mod for key, mod in mods.items()
              if mod["domain"] == "ducat_crafted" and mod["generation_type"] in {"prefix", "suffix"}
              and key.startswith("DeepwaterHazard")}
identifiers.update(ducat_mods)
compiled = {identifier: {key: mod[key] for key in fields} for identifier, mod in mods.items()
            if identifier in identifiers and mod["generation_type"] in generation}
result = {
    "patch": PATCH, "source": {"repo": REPOSITORY, "commit": COMMIT},
    "hashes": {name: hashlib.sha256(content).hexdigest() for name, content in raw.items()},
    "mods": compiled, "fossils": fossils, "bench": bench,
    "benchMods": {identifier: {key: mods[identifier][key] for key in ["text", "required_level", "generation_type"]}
                  for identifier in sorted({row["actions"]["add_explicit_mod"] for row in bench}
                                           - {None})},
    "currencies": {key: {"name": value["name"], "description": value.get("properties", {}).get("description"),
                         "release": value["release_state"]} for key, value in bases.items()
                   if value["item_class"] in ["StackableCurrency", "DeepwaterCurrency"] or "/Deepwater/" in key},
}
encoded = '{"_comment":"Generated GGG data from RePoE. cspell:disable",\n' + json.dumps(
    result, ensure_ascii=False, separators=(",", ":"))[1:]
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(encoded, encoding="utf-8")
def lua_string(value):
    return json.dumps(value, ensure_ascii=False)

lines = ["-- Generated from immutable RePoE game exports by tools/update_crafting_data.py.",
         "-- Item data (c) Grinding Gear Games", "return {"]
for key, mod in sorted(ducat_mods.items()):
    parts = [f"type = {lua_string(mod['generation_type'].title())}",
             f"affix = {lua_string(mod['name'])}"]
    parts.extend(lua_string(line) for line in mod["text"].splitlines())
    parts.append("statOrder = { " + ", ".join(str(100000 + i) for i, _ in enumerate(mod["text"].splitlines())) + " }")
    parts.append("tradeHashes = { }")
    parts.extend([f"level = {mod['required_level']}", f"group = {lua_string(mod['groups'][0])}"])
    for name, values in [("weightKey", [w["tag"] for w in mod["spawn_weights"]]),
                         ("weightVal", [w["weight"] for w in mod["spawn_weights"]]),
                         ("modTags", mod["implicit_tags"])]:
        parts.append(name + " = { " + ", ".join(lua_string(v) if isinstance(v, str) else str(v) for v in values) + " }")
    lines.append("\t[" + lua_string(key) + "] = { " + ", ".join(parts) + " },")
lines.append("}")
(ROOT / "src" / "Data" / "ModDucat.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Compiled {len(compiled)} native modifier records for {PATCH}")
