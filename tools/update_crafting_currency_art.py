"""Bundle currency artwork from the same immutable export as the crafting model."""
# cspell:ignore katakohi ukatoa
import argparse
import concurrent.futures
import hashlib
import json
import struct
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "src/Assets/Crafting/Currency"
METHODS = {
    "beast_max_links": "Imprinted Bestiary Orb",
    "beast_talisman_imprint": "Imprinted Bestiary Orb",
    "omen_connections": "Omen of Connections",
    "omen_trichromatism": "Omen of Trichromatism",
    "transmute": "Orb of Transmutation", "alteration": "Orb of Alteration",
    "augmentation": "Orb of Augmentation", "regal": "Regal Orb", "alchemy": "Orb of Alchemy",
    "chaos": "Chaos Orb", "exalt": "Exalted Orb", "annul": "Orb of Annulment",
    "scour": "Orb of Scouring", "divine": "Divine Orb", "vaal": "Vaal Orb",
    "chromatic": "Chromatic Orb", "jeweller": "Jeweller's Orb", "fusing": "Orb of Fusing",
    "blessed": "Blessed Orb", "sacred": "Sacred Orb", "conflict": "Orb of Conflict",
    "fracture": "Fracturing Orb", "awakener": "Awakener's Orb", "dominance": "Orb of Dominance",
    "veiled_orb": "Veiled Exalted Orb", "veiled_chaos": "Veiled Chaos Orb",
    "eldritch_exalt": "Eldritch Exalted Orb", "eldritch_annul": "Eldritch Orb of Annulment",
    "eldritch_chaos": "Eldritch Chaos Orb", "eldritch_implicit": "Lesser Eldritch Ember",
    "tainted_chromatic": "Tainted Chromatic Orb", "tainted_jeweller": "Tainted Jeweller's Orb",
    "tainted_fusing": "Tainted Orb of Fusing", "tainted_chaos": "Tainted Chaos Orb",
    "tainted_exalt": "Tainted Exalted Orb", "tainted_catalyst": "Tainted Catalyst",
    "binding": "Orb of Binding", "remembrance": "Orb of Remembrance", "unravelling": "Orb of Unravelling",
    "foulborn_augmentation": "Foulborn Orb of Augmentation", "foulborn_regal": "Foulborn Regal Orb",
    "foulborn_exalt": "Foulborn Exalted Orb", "ducat_cyaxan": "Cyaxan's Ducat",
    "ducat_brinehook": "Brinehook's Ducat", "ducat_genteel": "The Genteel's Ducat",
    "ducat_merrick": "Merrick's Ducat", "ducat_rotmother": "Rotmother's Ducat",
    "ducat_kishara": "Kishara's Ducat", "ducat_tzamoto": "Tzamoto's Ducat",
    "ducat_katakohi": "Katakohi's Ducat", "ducat_ukatoa": "Ukatoa's Ducat",
    "quality": "Armourer's Scrap", "tainted_quality": "Tainted Armourer's Scrap",
    "fossil": "Primitive Chaotic Resonator", "essence": "Deafening Essence of Greed",
    "harvest_reforge": "Primal Crystallised Lifeforce", "harvest_augment": "Primal Crystallised Lifeforce",
    "harvest_resistance": "Primal Crystallised Lifeforce", "catalyst": "Fertile Catalyst",
}


def check():
    crafting = json.loads((ROOT / "src/Data/Crafting/3.29.json").read_text())
    manifest = json.loads((ROOT / "src/Assets/Crafting/currencies.json").read_text())
    assert manifest["source"] == crafting["source"], "Currency artwork source differs from crafting data"
    assert manifest["baseItemsSha256"] == crafting["hashes"]["base_items.json"], "Currency export checksum differs"
    paths = set()
    for entry in manifest["items"].values():
        path = (ROOT / "src" / entry["path"]).resolve()
        assert path.parent == ASSETS.resolve() and path.suffix == ".png", "Currency image escapes its asset folder"
        content = path.read_bytes()
        assert content.startswith(b"\x89PNG\r\n\x1a\n"), path
        assert hashlib.sha256(content).hexdigest() == entry["sha256"], path
        assert struct.unpack(">II", content[16:24]) == (entry["width"], entry["height"]), path
        paths.add(path)
    assert paths == {path.resolve() for path in ASSETS.glob("*.png")}, "Missing or unreferenced currency artwork"
    for method, name in METHODS.items():
        assert manifest["items"][manifest["methods"][method]]["name"] == name, method
    assert any(entry["name"] == "Glassblower's Bauble" for entry in manifest["items"].values())
    return len(paths)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-items", type=Path, help="Use a cached export after verifying its pinned checksum")
    parser.add_argument("--check", action="store_true", help="Verify bundled provenance, dimensions and hashes offline")
    args = parser.parse_args()
    if args.check:
        print(f"Verified {check()} bundled currency images")
        return
    crafting = json.loads((ROOT / "src/Data/Crafting/3.29.json").read_text())
    source = crafting["source"]
    url = f"https://raw.githubusercontent.com/{source['repo']}/{source['commit']}/data/base_items.json"
    raw = args.base_items.read_bytes() if args.base_items else urllib.request.urlopen(url, timeout=30).read()
    assert hashlib.sha256(raw).hexdigest() == crafting["hashes"]["base_items.json"], "Pinned export changed"
    bases = json.loads(raw)
    wanted = set(METHODS.values())
    wanted.update({"Potent Chaotic Resonator", "Powerful Chaotic Resonator", "Prime Chaotic Resonator", "Glassblower's Bauble", "Wild Crystallised Lifeforce", "Vivid Crystallised Lifeforce", "Sacred Crystallised Lifeforce", "Crystallised Rancour"})
    entries = {key: value for key, value in bases.items() if value.get("visual_identity", {}).get("dds_file")
               and (value["name"] in wanted or value["item_class"] == "StackableCurrency" and
                    any(word in value["name"] for word in ("Essence of", "Fossil", "Catalyst", "Eldritch Ember", "Eldritch Ichor", "Resonator", "Whetstone", "Exalted Orb")))}
    ASSETS.mkdir(exist_ok=True)
    previous = ROOT / "src/Assets/Crafting/currencies.json"
    known = {}
    if previous.exists():
        old = json.loads(previous.read_text())
        if old.get("source") == source and old.get("baseItemsSha256") == hashlib.sha256(raw).hexdigest():
            known = {entry["url"]: entry for entry in old.get("items", {}).values()}

    def download(art):
        name = hashlib.sha256(art.encode()).hexdigest()[:20] + ".png"
        url = "https://web.poecdn.com/image/" + urllib.parse.quote(art.removesuffix(".dds") + ".png", safe="/")
        destination = ASSETS / name
        content = destination.read_bytes() if destination.exists() and url in known else b""
        if not content or hashlib.sha256(content).hexdigest() != known.get(url, {}).get("sha256"):
            content = urllib.request.urlopen(url, timeout=30).read()
        assert content.startswith(b"\x89PNG\r\n\x1a\n"), "Currency artwork is not PNG"
        destination.write_bytes(content)
        width, height = struct.unpack(">II", content[16:24])
        return art, {"path": "Assets/Crafting/Currency/" + name, "url": url, "width": width, "height": height,
                     "sha256": hashlib.sha256(content).hexdigest()}

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        images = dict(executor.map(download, sorted({v["visual_identity"]["dds_file"] for v in entries.values()})))
    by_id = {key: {"name": value["name"], **images[value["visual_identity"]["dds_file"]]} for key, value in sorted(entries.items())}
    names = {value["name"]: key for key, value in by_id.items()}
    missing = wanted - names.keys()
    assert not missing, f"Missing pinned currency definitions: {sorted(missing)}"
    manifest = {"_comment": "Generated GGG currency art. cspell:disable", "copyright": "Item artwork (c) Grinding Gear Games.",
                "source": source, "baseItemsSha256": hashlib.sha256(raw).hexdigest(), "items": by_id,
                "methods": {method: names[name] for method, name in sorted(METHODS.items())}}
    (ROOT / "src/Assets/Crafting/currencies.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Bundled {len(images)} currency images for {len(by_id)} definitions and {len(METHODS)} actions")


if __name__ == "__main__":
    main()
