"""Bundle base-item artwork from PoB's pinned crafting export and GGG's CDN."""
import concurrent.futures
import hashlib
import json
import re
import struct
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "src/Assets/Crafting"


def main():
    crafting = json.loads((ROOT / "src/Data/Crafting/3.29.json").read_text())
    source = crafting["source"]
    url = f"https://raw.githubusercontent.com/{source['repo']}/{source['commit']}/data/base_items.json"
    with urllib.request.urlopen(url, timeout=60) as response:
        raw = response.read()
    if hashlib.sha256(raw).hexdigest() != crafting["hashes"]["base_items.json"]:
        raise ValueError("Base artwork export does not match the pinned crafting data")
    names = set()
    for path in (ROOT / "src/Data/Bases").glob("*.lua"):
        names.update(re.findall(r'itemBases\["([^"]+)"\]', path.read_text()))
    entries = {}
    for base in json.loads(raw).values():
        art = base.get("visual_identity", {}).get("dds_file")
        if base["name"] in names and art:
            entries[base["name"]] = art
    (ASSETS / "Items").mkdir(exist_ok=True)

    def download(art):
        name = hashlib.sha256(art.encode()).hexdigest()[:20] + ".png"
        url = "https://web.poecdn.com/image/" + art.removesuffix(".dds") + ".png"
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                content = response.read()
            if not content.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError("Not a PNG")
            (ASSETS / "Items" / name).write_bytes(content)
            width, height = struct.unpack(">II", content[16:24])
            return art, {"path": "Assets/Crafting/Items/" + name, "url": url, "width": width, "height": height,
                         "sha256": hashlib.sha256(content).hexdigest()}
        except (OSError, ValueError) as error:
            return art, {"unavailable": str(error), "url": url}

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        images = dict(executor.map(download, sorted(set(entries.values()))))
    manifest = {"_comment": "Generated GGG artwork metadata. cspell:disable",
                "copyright": "Item artwork (c) Grinding Gear Games.", "source": source,
                "baseItemsSha256": hashlib.sha256(raw).hexdigest(),
                "bases": {name: images[art] for name, art in sorted(entries.items())}}
    (ASSETS / "items.json").write_text(json.dumps(manifest, indent=2) + "\n")
    missing = sum("path" not in entry for entry in images.values())
    print(f"Bundled {len(images)-missing} item images; {missing} unavailable (equipment silhouette fallback).")


if __name__ == "__main__":
    main()
