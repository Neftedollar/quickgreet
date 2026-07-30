#!/usr/bin/env python3
"""Generates a colour scheme from an image.

Extracts a seed colour from the wallpaper and expands it into a Material
You palette, printing the JSON that quickgreet reads as scheme.json.

    gen-scheme.py wallpaper.jpg > /etc/quickgreet/scheme.json
    gen-scheme.py --light wallpaper.jpg
    gen-scheme.py --variant vibrant wallpaper.jpg

Optional. Without it, point schemePath at a hand-written file or at a
scheme another tool produced; the format is the same.

Requires python-materialyoucolor and Pillow.
"""

import argparse
import json
import sys

# Colour roles emitted, matching what the QML side reads.
ROLES = [
    "background", "onBackground",
    "surface", "surfaceDim", "surfaceBright",
    "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer",
    "surfaceContainerHigh", "surfaceContainerHighest",
    "onSurface", "onSurfaceVariant",
    "primary", "onPrimary", "primaryContainer", "onPrimaryContainer",
    "secondary", "onSecondary", "secondaryContainer", "onSecondaryContainer",
    "tertiary", "onTertiary", "tertiaryContainer", "onTertiaryContainer",
    "error", "onError", "errorContainer", "onErrorContainer",
    "outline", "outlineVariant",
]

# variant name -> (module suffix, class). The module names are snake_case
# while the classes are CamelCase, so neither can be derived from the other.
VARIANTS = {
    "tonalspot": ("tonal_spot", "SchemeTonalSpot"),
    "vibrant": ("vibrant", "SchemeVibrant"),
    "expressive": ("expressive", "SchemeExpressive"),
    "fidelity": ("fidelity", "SchemeFidelity"),
    "content": ("content", "SchemeContent"),
    "monochrome": ("monochrome", "SchemeMonochrome"),
    "neutral": ("neutral", "SchemeNeutral"),
    "rainbow": ("rainbow", "SchemeRainbow"),
    "fruitsalad": ("fruit_salad", "SchemeFruitSalad"),
}


def seed_from_image(path, quality=1):
    """Picks the most representative colour of an image."""
    from PIL import Image
    from materialyoucolor.quantize import QuantizeCelebi
    from materialyoucolor.score.score import Score

    image = Image.open(path).convert("RGB")

    # Downscale first: quantising a full-size photo is slow and the extra
    # pixels do not change which colour dominates.
    image.thumbnail((256, 256))

    # get_flattened_data replaced getdata in newer Pillow; both yield a
    # sequence of per-pixel RGB tuples, which QuantizeCelebi wants as lists.
    raw = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    pixels = [list(px) for px in raw][::quality]

    result = QuantizeCelebi(pixels, 128)
    return Score.score(result)[0]


def build(seed_argb, variant, dark, contrast=0.0):
    import importlib

    from materialyoucolor.hct import Hct

    suffix, cls_name = VARIANTS[variant]
    module = importlib.import_module(f"materialyoucolor.scheme.scheme_{suffix}")
    cls = getattr(module, cls_name)

    from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors

    scheme = cls(Hct.from_int(seed_argb), dark, contrast)

    # Roles are not attributes of the scheme. Each one is a DynamicColor
    # descriptor on MaterialDynamicColors that resolves against a scheme.
    colours = {}
    for role in ROLES:
        descriptor = getattr(MaterialDynamicColors, role, None)
        if descriptor is None or not hasattr(descriptor, "get_hct"):
            continue
        rgba = descriptor.get_hct(scheme).to_rgba()
        # [r, g, b, a]; alpha is unused here.
        colours[role] = "{:02x}{:02x}{:02x}".format(*rgba[:3])

    return colours


def main():
    ap = argparse.ArgumentParser(description="generate a quickgreet colour scheme from an image")
    ap.add_argument("image", help="source image")
    ap.add_argument("--variant", choices=sorted(VARIANTS), default="tonalspot")
    ap.add_argument("--light", action="store_true", help="light mode (default is dark)")
    ap.add_argument("--contrast", type=float, default=0.0, help="-1.0 to 1.0")
    args = ap.parse_args()

    try:
        seed = seed_from_image(args.image)
    except FileNotFoundError:
        print(f"no such image: {args.image}", file=sys.stderr)
        return 1
    except ImportError as e:
        print(f"missing dependency: {e}", file=sys.stderr)
        print("needs python-materialyoucolor and Pillow", file=sys.stderr)
        return 1

    colours = build(seed, args.variant, not args.light, args.contrast)

    json.dump({
        "mode": "light" if args.light else "dark",
        "variant": args.variant,
        "source": args.image,
        "colours": colours,
    }, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
