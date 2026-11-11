"""Rebuild supplemental crafting data from immutable RePoE game exports."""
# cspell:ignore repoe
import hashlib
import json
import re
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "repoe-fork/repoe-fork.github.io"
COMMIT = "ae6d85a5c36857e08819852ab8732239294aba59"
PATCH = "3.29.3.6"
FILES = ["mods.json", "fossils.json", "base_items.json", "crafting_bench_options.json"]
raw = {}
for name in FILES:
    with urlopen(f"https://raw.githubusercontent.com/{REPOSITORY}/{COMMIT}/data/{name}", timeout=60) as response:
        raw[name] = response.read()
mods, fossils, bases, bench = (json.loads(raw[name]) for name in FILES)
identifiers = set()
for source in (ROOT / "src" / "Data").glob("*.lua"):
    if source.name.startswith("Mod") or source.name in ["BeastCraft.lua", "Essence.lua"]:
        identifiers.update(re.findall(r'\["([^"]+)"\]\s*=', source.read_text(encoding="utf-8-sig")))
fields = ["groups", "stats", "domain", "implicit_tags", "adds_tags", "generation_weights",
          "spawn_weights", "is_essence_only", "required_level", "generation_type"]
generation = {"prefix", "suffix", "corrupted", "searing_exarch_implicit", "eater_of_worlds_implicit", "synthesis_a"}
compiled = {identifier: {key: mod[key] for key in fields} for identifier, mod in mods.items()
            if identifier in identifiers and mod["generation_type"] in generation}
result = {
    "patch": PATCH, "source": {"repo": REPOSITORY, "commit": COMMIT},
    "hashes": {name: hashlib.sha256(content).hexdigest() for name, content in raw.items()},
    "mods": compiled, "fossils": fossils, "bench": bench,
    "currencies": {key: {"name": value["name"], "description": value.get("properties", {}).get("description"),
                         "release": value["release_state"]} for key, value in bases.items()
                   if value["item_class"] in ["StackableCurrency", "DeepwaterCurrency"] or "/Deepwater/" in key},
}
encoded = '{"_comment":"Generated GGG data from RePoE. cspell:disable",\n' + json.dumps(
    result, ensure_ascii=False, separators=(",", ":"))[1:]
destination = ROOT / "src" / "Data" / "Crafting" / "3.29.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(encoded, encoding="utf-8")
print(f"Compiled {len(compiled)} native modifier records for {PATCH}")
