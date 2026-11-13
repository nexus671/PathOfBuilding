"""Render headless draw records with PoB's bundled bitmap fonts (requires Pillow)."""
# cspell:ignore putalpha getchannel getpixel LANCZOS
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
        left, top, right, bottom = [round(v * (texture.width if i % 2 == 0 else texture.height)) for i, v in enumerate(uv)]
        texture = texture.crop((min(left, right), min(top, bottom), max(left, right), max(top, bottom)))
        if right < left:
            texture = texture.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if bottom < top:
            texture = texture.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return texture


def bundled_texture(asset):
    path = (ROOT / "src" / asset).resolve()
    if not any(path.is_relative_to((ROOT / "src" / folder).resolve()) for folder in ("Assets", "TreeData")):
        raise ValueError("Texture outside bundled assets")
    return path


def rect_texture(asset, uv, size):
    if uv and (min(uv) < 0 or max(uv) > 1) and uv[2] > uv[0] and uv[3] > uv[1]:
        # Native tree backgrounds repeat outside 0..1. Tile at output resolution
        # instead of allocating a potentially enormous source-image crop.
        tile_width, tile_height = size[0] / (uv[2] - uv[0]), size[1] / (uv[3] - uv[1])
        tile = texture_region(str(asset), None).resize((max(1, math.ceil(tile_width)), max(1, math.ceil(tile_height))), Image.Resampling.LANCZOS)
        result = Image.new("RGBA", size)
        for x in range(math.floor(uv[0]), math.ceil(uv[2])):
            for y in range(math.floor(uv[1]), math.ceil(uv[3])):
                result.alpha_composite(tile, (round((x - uv[0]) * tile_width), round((y - uv[1]) * tile_height)))
        return result
    return texture_region(str(asset), tuple(uv) if uv else None).resize(size, Image.Resampling.LANCZOS)


def textured_quad(layer, command):
    """Rasterize two affine triangles using the native quad's four UV pairs."""
    texture = texture_region(str(bundled_texture(command["asset"])), None)
    points = list(zip(command["points"][::2], command["points"][1::2]))
    uv = command.get("uv") or [0, 0, 1, 0, 1, 1, 0, 1]
    source = [(uv[i] * texture.width, uv[i + 1] * texture.height) for i in range(0, 8, 2)]
    for indices in ((0, 1, 2), (0, 2, 3)):
        target = [points[i] for i in indices]
        (x1, y1), (x2, y2), (x3, y3) = target
        determinant = (x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)
        if abs(determinant) < 1e-8:
            continue
        box = (max(0, math.floor(min(p[0] for p in target))), max(0, math.floor(min(p[1] for p in target))),
               min(layer.width, math.ceil(max(p[0] for p in target))), min(layer.height, math.ceil(max(p[1] for p in target))))
        if box[2] <= box[0] or box[3] <= box[1]:
            continue
        coefficients = []
        for axis in (0, 1):
            v1, v2, v3 = [source[i][axis] for i in indices]
            a = ((v2 - v1) * (y3 - y1) - (v3 - v1) * (y2 - y1)) / determinant
            b = ((x2 - x1) * (v3 - v1) - (x3 - x1) * (v2 - v1)) / determinant
            coefficients += [a, b, v1 - a * x1 - b * y1 + a * box[0] + b * box[1]]
        size = (box[2] - box[0], box[3] - box[1])
        patch = texture.transform(size, Image.Transform.AFFINE, coefficients, Image.Resampling.BILINEAR)
        patch = ImageChops.multiply(patch, Image.new("RGBA", size, rgba(command["color"])))
        mask = Image.new("L", size)
        ImageDraw.Draw(mask).polygon([(x - box[0], y - box[1]) for x, y in target], fill=255)
        patch.putalpha(ImageChops.multiply(patch.getchannel("A"), mask))
        layer.alpha_composite(patch, box[:2])


def render(frame):
    canvas = Image.new("RGBA", (frame["width"], frame["height"]), (18, 18, 18, 255))
    audit = {"lowContrast": [], "horizontalClipping": [], "controlClipping": [], "controlOverlaps": [], "texturedPlaceholders": 0,
             "limitations": frame.get("limitations", [])}
    controls = frame.get("controls", [])
    dialog = frame.get("dialog")
    if dialog and (dialog["x"] < 0 or dialog["y"] < 0 or dialog["x"] + dialog["width"] > frame["width"] or dialog["y"] + dialog["height"] > frame["height"]):
        audit["controlClipping"].append({"key": "dialog-title-and-body", "bounds": dialog})
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
    commands = sorted(frame["commands"], key=lambda c: (c["layer"], c["sublayer"], c["order"]))
    for command in commands:
        clip = command["clip"]
        box = (max(0, round(clip[0])), max(0, round(clip[1])),
               min(canvas.width, round(clip[0] + clip[2])), min(canvas.height, round(clip[1] + clip[3])))
        if box[2] <= box[0] or box[3] <= box[1]:
            continue
        if command["kind"] == "rect":
            x, y, w, h = [command[k] for k in ("x", "y", "width", "height")]
            if x + w <= box[0] or y + h <= box[1] or x >= box[2] or y >= box[3]:
                continue
            box = (max(box[0], math.floor(x)), max(box[1], math.floor(y)), min(box[2], math.ceil(x + w)), min(box[3], math.ceil(y + h)))
        elif command["kind"] == "polygon":
            xs, ys = command["points"][::2], command["points"][1::2]
            if max(xs) <= box[0] or max(ys) <= box[1] or min(xs) >= box[2] or min(ys) >= box[3]:
                continue
            box = (max(box[0], math.floor(min(xs))), max(box[1], math.floor(min(ys))), min(box[2], math.ceil(max(xs))), min(box[3], math.ceil(max(ys))))
        layer = Image.new("RGBA", canvas.size)
        draw = ImageDraw.Draw(layer)
        if command["kind"] == "rect":
            rect = [command[k] for k in ("x", "y", "width", "height")]
            draw.rectangle((rect[0], rect[1], rect[0] + rect[2] - 1, rect[1] + rect[3] - 1), fill=rgba(command["color"]))
            if command.get("asset"):
                asset = bundled_texture(command["asset"])
                texture = rect_texture(asset, command.get("uv"), (max(1, round(rect[2])), max(1, round(rect[3]))))
                texture = ImageChops.multiply(texture, Image.new("RGBA", texture.size, rgba(command["color"])))
                layer = Image.new("RGBA", canvas.size)
                layer.alpha_composite(texture, (round(rect[0] + (rect[2]-texture.width)/2), round(rect[1] + (rect[3]-texture.height)/2)))
        elif command["kind"] == "polygon":
            points = command["points"]
            if command.get("asset"):
                textured_quad(layer, command)
            else:
                draw.polygon(list(zip(points[::2], points[1::2])), fill=rgba(command["color"]))
        elif command["kind"] == "text":
            entries, atlas = glyphs(command["font"], command["fontHeight"])
            x, y, height = command["x"], command["y"], command["height"]
            scale = height / command["fontHeight"]
            color, index = command["color"], 0
            # Native tooltips and expanded lists use the overlay sublayer. They
            # can cover neighbouring controls, but must still fit their viewport.
            overlay = command["sublayer"] >= 100
            critical = overlay or any(contains(r, x + 1, y + height / 2) for r in frame.get("regions", []))
            if critical and y >= clip[1] and y + height <= clip[1] + clip[3]:
                if x < clip[0] or x + command["width"] > clip[0] + clip[2] + 1:
                    audit["horizontalClipping"].append(command["text"])
            center_x = x + command["width"] / 2
            center_y = y + height / 2
            containers = [c for c in frame.get("controls", []) if c["width"] >= 40 and c["height"] <= 40
                          and contains([c["x"], c["y"], c["width"], c["height"]], center_x, center_y)]
            if not overlay and containers and contains(clip, center_x, center_y):
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
                    # Sample the composited background: native tooltips use a
                    # translucent black fill over controls and colour swatches.
                    sample_x, sample_y = math.floor(x), math.floor(y + height / 2)
                    shade = [18 / 255, 18 / 255, 18 / 255, 1]
                    if 0 <= sample_x < canvas.width and 0 <= sample_y < canvas.height:
                        shade = [channel / 255 for channel in canvas.getpixel((sample_x, sample_y))]
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
