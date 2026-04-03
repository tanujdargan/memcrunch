#!/usr/bin/env python3
"""Generate the MemCrunch app icon — a treemap pattern inside a rounded square."""

from PIL import Image, ImageDraw, ImageFont
import math, os, subprocess, sys

SIZE = 1024
CORNER = 220  # macOS icon corner radius at 1024px
PAD = 80      # inner padding for the treemap pattern

# Color palette — matches the app's file type categories
COLORS = [
    "#3B82F6",  # blue (documents)
    "#22C55E",  # green (images)
    "#A855F7",  # purple (video)
    "#06B6D4",  # cyan (code)
    "#F97316",  # orange (audio)
    "#EC4899",  # pink (apps)
    "#EF4444",  # red (archives)
]

BG_COLOR = "#1a1a2e"
BORDER_COLOR = "#2a2a4a"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def rounded_rect_mask(size, radius):
    """Create a rounded rectangle mask."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def draw_treemap_block(draw, x, y, w, h, color, gap=6):
    """Draw a single treemap block with rounded corners."""
    if w < 4 or h < 4:
        return
    r = min(12, w // 6, h // 6)
    draw.rounded_rectangle(
        [x + gap, y + gap, x + w - gap, y + h - gap],
        radius=r,
        fill=hex_to_rgb(color),
    )


def generate_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background rounded square
    draw.rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1],
        radius=CORNER,
        fill=hex_to_rgb(BG_COLOR),
        outline=hex_to_rgb(BORDER_COLOR),
        width=3,
    )

    # Draw a treemap-like pattern — pushed down to make room for big text
    x0, y0 = PAD + 20, PAD + 170
    w0, h0 = SIZE - PAD * 2 - 40, SIZE - PAD * 2 - 190

    # Large block (top-left, ~40% area) — blue
    bw = int(w0 * 0.55)
    bh = int(h0 * 0.52)
    draw_treemap_block(draw, x0, y0, bw, bh, COLORS[0])

    # Medium block (top-right, ~25%) — green
    draw_treemap_block(draw, x0 + bw, y0, w0 - bw, int(bh * 0.65), COLORS[1])

    # Small block (top-right-bottom) — purple
    draw_treemap_block(draw, x0 + bw, y0 + int(bh * 0.65), w0 - bw, bh - int(bh * 0.65), COLORS[2])

    # Bottom row — 4 blocks
    row_y = y0 + bh
    row_h = h0 - bh
    widths = [0.30, 0.25, 0.25, 0.20]
    colors_row = [COLORS[3], COLORS[4], COLORS[5], COLORS[6]]
    cx = x0
    for i, (frac, col) in enumerate(zip(widths, colors_row)):
        bw2 = int(w0 * frac)
        if i == len(widths) - 1:
            bw2 = x0 + w0 - cx  # fill remaining
        draw_treemap_block(draw, cx, row_y, bw2, row_h, col)
        cx += bw2

    # "MemCrunch" text — large and readable
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFPro-Bold.otf", 120)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 120)
        except:
            font = ImageFont.load_default()

    draw.text(
        (PAD + 10, PAD + 10),
        "MemCrunch",
        fill=(255, 255, 255, 230),
        font=font,
    )

    # Apply rounded mask
    mask = rounded_rect_mask(SIZE, CORNER)
    img.putalpha(mask)

    return img


def create_iconset(img, output_dir):
    """Create .iconset directory with all required sizes."""
    iconset_dir = os.path.join(output_dir, "MemCrunch.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [16, 32, 128, 256, 512]
    for s in sizes:
        # Standard
        resized = img.resize((s, s), Image.LANCZOS)
        resized.save(os.path.join(iconset_dir, f"icon_{s}x{s}.png"))
        # @2x
        resized2x = img.resize((s * 2, s * 2), Image.LANCZOS)
        resized2x.save(os.path.join(iconset_dir, f"icon_{s}x{s}@2x.png"))

    # Also save 1024 directly
    img.save(os.path.join(iconset_dir, "icon_512x512@2x.png"))

    return iconset_dir


def main():
    output_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(output_dir)

    print("Generating icon...")
    img = generate_icon()

    # Save full-size PNG
    png_path = os.path.join(project_root, "MemCrunch", "Resources", "AppIcon.png")
    img.save(png_path)
    print(f"  Saved {png_path}")

    # Create .iconset and convert to .icns
    iconset_dir = create_iconset(img, project_root)
    icns_path = os.path.join(project_root, "MemCrunch", "Resources", "AppIcon.icns")
    result = subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        print(f"  Created {icns_path}")
        # Clean up iconset
        subprocess.run(["rm", "-rf", iconset_dir])
    else:
        print(f"  iconutil failed: {result.stderr}")
        print(f"  .iconset saved at {iconset_dir}")

    print("Done!")


if __name__ == "__main__":
    main()
