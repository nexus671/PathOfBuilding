"""Rebuild bundled Atlas graphs from pinned, official GGG Standard exports."""
import hashlib
import json
import math
from pathlib import Path
from urllib.request import urlopen

VERSIONS = {
    "3.27.0": "dd12728df527cf96a93f91cbee7d5951285b8883",
    "3.29.1": "0ae2e0f94f266fc21c86ee8dd561d7b559bf2db4",
}
DESTINATION = Path(__file__).resolve().parents[1] / "src" / "Data" / "Atlas"
ANGLES = [0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330]

for version, commit in VERSIONS.items():
    source = f"https://raw.githubusercontent.com/grindinggear/atlastree-export/{commit}/data.json"
    with urlopen(source, timeout=30) as response:
        raw = response.read()
    data = json.loads(raw)
    assert data["tree"] == "Atlas"
    nodes = {}
    start = int(data["nodes"]["root"]["out"][0])
    for key, node in data["nodes"].items():
        if key == "root" or node.get("isMastery"):
            continue
        group = data["groups"][str(node["group"])]
        count = data["constants"]["skillsPerOrbit"][node["orbit"]]
        index = node["orbitIndex"]
        angle = math.radians(ANGLES[index] if count == 16 else 360 * index / count)
        radius = data["constants"]["orbitRadii"][node["orbit"]]
        nodes[key] = {
            "id": int(key), "name": node["name"] or "Atlas start", "stats": node["stats"],
            "x": round(group["x"] + math.sin(angle) * radius, 2),
            "y": round(group["y"] - math.cos(angle) * radius, 2),
            "links": sorted({int(other) for other in node["out"] + node["in"]
                             if other != "root" and not data["nodes"][other].get("isMastery")}),
            "kind": "keystone" if node.get("isKeystone") else "notable" if node.get("isNotable")
                    else "gateway" if node.get("isWormhole") else "small",
            "grantedPoints": node.get("grantedPassivePoints", 0),
        }
    result = {
        "version": version, "mode": "standard", "source": source, "commit": commit,
        "sha256": hashlib.sha256(raw).hexdigest(), "start": start,
        "maxPoints": data["points"]["totalPoints"], "nodes": nodes,
    }
    DESTINATION.mkdir(parents=True, exist_ok=True)
    # Preserve the game's spelling in generated data, as with other GGG exports.
    encoded = '{"_comment":"Generated official GGG data. cspell:disable",\n' + json.dumps(
        result, ensure_ascii=False, separators=(",", ":"))[1:]
    (DESTINATION / f"{version}.json").write_text(encoded, encoding="utf-8")
    print(f"{version}: {len(nodes)} allocatable nodes; source {result['sha256']}")
