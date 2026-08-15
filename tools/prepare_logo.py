#!/usr/bin/env python3
"""Prepares the supplied gold emblem as a transparent square application icon."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "WhatsApp Image 2026-08-14 at 23.26.13.jpeg"
OUTPUT = ROOT / "assets" / "ui" / "sanlaq_logo.png"


def transparency_for(pixel: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    red, green, blue, alpha = pixel
    # The source is a gold emblem on a nearly-white JPEG background.
    # Preserve gold highlights, while fading only neutral white pixels.
    color_spread = max(red, green, blue) - min(red, green, blue)
    # JPEG white remains very bright but has almost no color spread; gold is saturated.
    opacity = max(0.0, min(1.0, (color_spread - 10.0) / 24.0))
    return red, green, blue, round(alpha * opacity)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    image.putdata([transparency_for(pixel) for pixel in image.getdata()])
    bbox = image.getbbox()
    if bbox is None:
        raise RuntimeError("Logo contains no non-transparent pixels")
    image = image.crop(bbox)
    image.thumbnail((440, 440), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    icon.alpha_composite(image, ((512 - image.width) // 2, (512 - image.height) // 2))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUTPUT)
    print(f"ICON READY: {OUTPUT}")


if __name__ == "__main__":
    main()
