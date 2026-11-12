"""Record real bundled image dimensions for native headless layout and UVs."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sizes = {"_comment": "Generated image dimensions. cspell:disable"}
for folder in ("Assets", "TreeData"):
    for path in sorted((ROOT / "src" / folder).rglob("*")):
        if path.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".tga"):
            with Image.open(path) as image:
                sizes[path.relative_to(ROOT / "src").as_posix()] = list(image.size)
destination = ROOT / "src/Data/HeadlessImageSizes.json"
destination.write_text(json.dumps(sizes, separators=(",", ":")) + "\n", encoding="utf-8")
print(f"Recorded {len(sizes) - 1} bundled image sizes")
