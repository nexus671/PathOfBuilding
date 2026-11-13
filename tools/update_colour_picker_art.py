"""Build the native HSV picker textures from geometry; --check is offline."""
# cspell:ignore putpixel
import argparse
import colorsys
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "src/Assets/LootFilters"
MANIFEST = DEST / "colour-picker.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generator_digest():
    return hashlib.sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def images():
    wheel = Image.new("RGBA", (256, 256))
    pixels = wheel.load()
    radius = 127
    for y in range(256):
        for x in range(256):
            dx, dy = x - 127.5, y - 127.5
            distance = math.hypot(dx, dy)
            coverage = max(0, min(1, radius + 0.5 - distance))
            hue = (math.atan2(dy, dx) / (2 * math.pi)) % 1
            rgb = colorsys.hsv_to_rgb(hue, min(1, distance / radius), 1)
            pixels[x, y] = tuple(round(c * 255) for c in rgb) + (round(coverage * 255),)
    value = Image.new("RGBA", (16, 256))
    alpha = Image.new("RGBA", (16, 256))
    for y in range(256):
        for x in range(16):
            value.putpixel((x, y), (255 - y, 255 - y, 255 - y, 255))
            alpha.putpixel((x, y), (255, 255, 255, 255 - y))
    checker = Image.new("RGBA", (512, 512))
    for y in range(512):
        for x in range(512):
            shade = 110 if (x // 8 + y // 8) % 2 else 165
            checker.putpixel((x, y), (shade, shade, shade, 255))
    return {"colour-wheel.png": wheel, "colour-value.png": value,
            "colour-alpha.png": alpha, "colour-checker.png": checker}


def check():
    manifest = json.loads(MANIFEST.read_text())
    assert manifest["generatorSHA256"] == generator_digest(), "Regenerate colour-picker art after generator changes"
    assert set(manifest["images"]) == {"colour-wheel.png", "colour-value.png", "colour-alpha.png", "colour-checker.png"}
    for name, entry in manifest["images"].items():
        path = DEST / name
        assert digest(path) == entry["sha256"], f"Colour texture hash differs: {name}"
        with Image.open(path) as image:
            assert image.format == "PNG" and image.mode == "RGBA"
            assert list(image.size) == entry["size"], f"Colour texture dimensions differ: {name}"
            image.verify()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        check()
        print("Colour-picker textures verified")
        return
    DEST.mkdir(parents=True, exist_ok=True)
    entries = {}
    for name, image in images().items():
        path = DEST / name
        image.save(path)
        entries[name] = {"size": list(image.size), "sha256": digest(path)}
    MANIFEST.write_text(json.dumps({"schemaVersion": 1, "source": "Generated HSV geometry and linear byte gradients",
        "generatorSHA256": generator_digest(), "images": entries}, indent=2) + "\n")
    check()
    print(f"Generated {len(entries)} colour-picker textures")


if __name__ == "__main__":
    main()
