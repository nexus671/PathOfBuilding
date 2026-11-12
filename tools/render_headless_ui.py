"""Render headless draw records with PoB's bundled bitmap fonts (requires Pillow)."""
# cspell:ignore putalpha getchannel LANCZOS
import argparse
import functools
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PALETTE = [(0, 0, 0), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255),
           (0, 255, 255), (255, 0, 255), (255, 255, 255), (128, 128, 128), (255, 128, 0)]
ESCAPE = re.compile(r"\^(?:x([0-9a-fA-F]{6})|([0-9]))")


@functools.lru_cache(maxsize=None)
def glyphs(family, height):
    records, current = {}, None
    for line in (ROOT / "runtime/SimpleGraphic/Fonts" / (family + ".tgf")).read_text().splitlines():
        match = re.match(r"HEIGHT (\d+)", line)
        if match:
            current = int(match[1])
            records[current] = []
        elif line.startswith("GLYPH"):
            records[current].append(tuple(map(int, re.findall(r"-?\d+", line.split(";")[0]))))
    atlas = Image.open(ROOT / "runtime/SimpleGraphic/Fonts" / f"{family}.{height}.tga").convert("RGBA")
    return records[height], atlas


def rgba(color):
    return tuple(round(max(0, min(1, value)) * 255) for value in color)


def contains(rect, x, y):
    return rect[0] <= x < rect[0] + rect[2] and rect[1] <= y < rect[1] + rect[3]


def contrast(first, second):
    def luminance(rgb):
        values = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb[:3]]
        return sum(a * b for a, b in zip(values, (0.2126, 0.7152, 0.0722)))
    a, b = sorted((luminance(first), luminance(second)))
    return (b + 0.05) / (a + 0.05)


@functools.lru_cache(maxsize=4096)
def texture_region(path, uv):
    texture = Image.open(path).convert("RGBA")
    if uv:
        texture = texture.crop(tuple(round(v * (texture.width if i % 2 == 0 else texture.height)) for i, v in enumerate(uv)))
    return texture


def render(frame):
    canvas = Image.new("RGBA", (frame["width"], frame["height"]), (18, 18, 18, 255))
    audit = {"lowContrast": [], "horizontalClipping": [], "controlClipping": [], "controlOverlaps": [], "texturedPlaceholders": 0,
             "limitations": frame.get("limitations", [])}
    controls = frame.get("controls", [])
    for i, first in enumerate(controls):
        if not first.get("group"):
            continue
        for second in controls[i+1:]:
            if first["group"] != second.get("group"):
                continue
            overlap_x = min(first["x"]+first["width"], second["x"]+second["width"]) - max(first["x"], second["x"])
            overlap_y = min(first["y"]+first["height"], second["y"]+second["height"]) - max(first["y"], second["y"])
            contained = any(a["x"] <= b["x"] and a["y"] <= b["y"] and a["x"]+a["width"] >= b["x"]+b["width"]
                            and a["y"]+a["height"] >= b["y"]+b["height"] for a, b in ((first, second), (second, first)))
            if overlap_x > 1 and overlap_y > 1 and not contained:
                audit["controlOverlaps"].append([first["key"], second["key"]])
    background = []
    commands = sorted(frame["commands"], key=lambda c: (c["layer"], c["sublayer"], c["order"]))
    for command in commands:
        clip = command["clip"]
        box = (max(0, round(clip[0])), max(0, round(clip[1])),
               min(canvas.width, round(clip[0] + clip[2])), min(canvas.height, round(clip[1] + clip[3])))
        if box[2] <= box[0] or box[3] <= box[1]:
            continue
        layer = Image.new("RGBA", canvas.size)
        draw = ImageDraw.Draw(layer)
        if command["kind"] == "rect":
            rect = [command[k] for k in ("x", "y", "width", "height")]
            draw.rectangle((rect[0], rect[1], rect[0] + rect[2] - 1, rect[1] + rect[3] - 1), fill=rgba(command["color"]))
            background.append((rect, clip, command["color"]))
            if command.get("asset"):
                asset = (ROOT / "src" / command["asset"]).resolve()
                if not asset.is_relative_to((ROOT / "src/Assets").resolve()):
                    raise ValueError("Texture outside bundled assets")
                texture = texture_region(str(asset), tuple(command["uv"]) if command.get("uv") else None)
                texture = texture.resize((max(1, round(rect[2])), max(1, round(rect[3]))), Image.Resampling.LANCZOS)
                texture = ImageChops.multiply(texture, Image.new("RGBA", texture.size, rgba(command["color"])))
                layer = Image.new("RGBA", canvas.size)
                layer.alpha_composite(texture, (round(rect[0] + (rect[2]-texture.width)/2), round(rect[1] + (rect[3]-texture.height)/2)))
        elif command["kind"] == "polygon":
            points = command["points"]
            draw.polygon(list(zip(points[::2], points[1::2])), fill=rgba(command["color"]))
        elif command["kind"] == "text":
            entries, atlas = glyphs(command["font"], command["fontHeight"])
            x, y, height = command["x"], command["y"], command["height"]
            scale = height / command["fontHeight"]
            color, index = command["color"], 0
            critical = any(contains(r, x + 1, y + height / 2) for r in frame.get("regions", []))
            if critical and y >= clip[1] and y + height <= clip[1] + clip[3]:
                if x < clip[0] or x + command["width"] > clip[0] + clip[2] + 1:
                    audit["horizontalClipping"].append(command["text"])
            center_x = x + command["width"] / 2
            center_y = y + height / 2
            containers = [c for c in frame.get("controls", []) if c["width"] >= 40 and c["height"] <= 40
                          and contains([c["x"], c["y"], c["width"], c["height"]], center_x, center_y)]
            if containers:
                control = min(containers, key=lambda c: c["width"] * c["height"])
                intentional_clip = (clip[0] >= control["x"] and clip[1] >= control["y"]
                                    and clip[0] + clip[2] <= control["x"] + control["width"]
                                    and clip[1] + clip[3] <= control["y"] + control["height"])
                if not intentional_clip and (x < control["x"] - 1 or x + command["width"] > control["x"] + control["width"] + 1):
                    audit["controlClipping"].append({"control": control["key"], "text": command["text"]})
            checked_colors = set()
            while index < len(command["text"]):
                match = ESCAPE.match(command["text"], index)
                if match:
                    rgb = tuple(bytes.fromhex(match[1])) if match[1] else PALETTE[int(match[2])]
                    color = [c / 255 for c in rgb] + [1]
                    index = match.end()
                    continue
                char = command["text"][index]
                index += 1
                if char == "\n":
                    x = command["x"]
                    y += height
                    continue
                gx, gy, width, left, right = entries[ord(char) if ord(char) < len(entries) else ord("?")]
                if char == "\t":
                    x = math.ceil(x + (width + left + right) * scale * 4)
                    continue
                if critical and not char.isspace() and tuple(color) not in checked_colors:
                    checked_colors.add(tuple(color))
                    shade = [18 / 255, 18 / 255, 18 / 255, 1]
                    for rect, region, candidate in reversed(background):
                        if contains(rect, x, y + height / 2) and contains(region, x, y + height / 2) and candidate[3] >= 0.95:
                            shade = candidate
                            break
                    if contrast(color, shade) < 3:
                        audit["lowContrast"].append(command["text"])
                x += left * scale
                if width:
                    glyph = atlas.crop((gx, gy, gx + width, gy + command["fontHeight"]))
                    glyph = glyph.resize((max(1, round(width * scale)), max(1, round(height))), Image.Resampling.BILINEAR)
                    ink = Image.new("RGBA", glyph.size, rgba(color))
                    ink.putalpha(ImageChops.multiply(glyph.getchannel("A"), ink.getchannel("A")))
                    layer.alpha_composite(ink, (round(x), round(y)))
                x = math.ceil(x + (width + right) * scale)
        if command.get("textured") and not command.get("asset"):
            audit["texturedPlaceholders"] += 1
        canvas.alpha_composite(layer.crop(box), box[:2])
    return canvas.convert("RGB"), audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Frame JSON or directory of frames")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true", help="Fail on unreadable or horizontally clipped list text")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    paths = sorted(args.input.glob("*.json")) if args.input.is_dir() else [args.input]
    assert paths, "No headless frames found"
    failures = 0
    for path in paths:
        frame = json.loads(path.read_text())
        if frame.get("schemaVersion") != 1 or "commands" not in frame:
            continue
        image, audit = render(frame)
        image.save(args.output / (path.stem + ".png"))
        (args.output / (path.stem + ".audit.json")).write_text(json.dumps(audit, indent=2))
        failures += len(audit["lowContrast"]) + len(audit["horizontalClipping"]) + len(audit["controlClipping"]) + len(audit["controlOverlaps"])
        print(path.name, "draws", len(frame["commands"]), "contrast", len(audit["lowContrast"]), "clipping", len(audit["horizontalClipping"]), "controls", len(audit["controlClipping"]) + len(audit["controlOverlaps"]))
    if args.check and failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
