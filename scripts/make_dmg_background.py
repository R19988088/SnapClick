#!/usr/bin/env python3
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))

W, H = 660, 400  # logical points; window content size

FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_INDEX_REGULAR = 0  # W3
FONT_INDEX_BOLD = 2     # W6


def load_font(size, bold=False):
    idx = FONT_INDEX_BOLD if bold else FONT_INDEX_REGULAR
    try:
        return ImageFont.truetype(FONT_PATH, size, index=idx)
    except Exception:
        return ImageFont.load_default()


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_vertical_gradient(img, top_color, mid_color, bottom_color):
    w, h = img.size
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        if t < 0.5:
            c = lerp(top_color, mid_color, t / 0.5)
        else:
            c = lerp(mid_color, bottom_color, (t - 0.5) / 0.5)
        for x in range(w):
            px[x, y] = c + (255,)


def draw_chevron(draw, cx, cy, size, thickness, color):
    # one ">" chevron centered at (cx, cy)
    half = size / 2
    points_top = [(cx - half * 0.6, cy - half), (cx + half * 0.6, cy)]
    points_bot = [(cx + half * 0.6, cy), (cx - half * 0.6, cy + half)]
    draw.line(points_top, fill=color, width=thickness, joint="curve")
    draw.line(points_bot, fill=color, width=thickness, joint="curve")


def render(scale):
    w, h = W * scale, H * scale
    img = Image.new("RGBA", (w, h), (255, 255, 255, 255))

    # Sky gradient: top blue -> warm horizon
    top = (122, 168, 214)
    mid = (176, 198, 220)
    bottom = (236, 224, 206)
    draw_vertical_gradient(img, top, mid, bottom)

    # subtle radial glow near top center
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = w // 2, int(h * 0.18)
    gr = int(w * 0.3)
    gd.ellipse([cx - gr, cy - gr, cx + gr, cy + gr], fill=(255, 255, 255, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=70 * scale))
    img = Image.alpha_composite(img, glow)

    draw = ImageDraw.Draw(img)

    # Brand name
    brand_font = load_font(14 * scale, bold=True)
    brand = "SnapClick"
    bw = draw.textlength(brand, font=brand_font)
    draw.text(((w - bw) / 2, int(h * 0.07)), brand, font=brand_font,
              fill=(255, 255, 255, 235))

    # Title
    title_font = load_font(38 * scale, bold=True)
    title = "\u8ba9 macOS \u6548\u7387\uff0c\u66f4\u8fd1\u4e00\u6b65"
    tw = draw.textlength(title, font=title_font)
    tx = (w - tw) / 2
    ty = int(h * 0.135)
    draw.text((tx, ty), title, font=title_font, fill=(255, 255, 255, 255))

    # Frosted card container
    card_margin_x = int(w * 0.06)
    card_top = int(h * 0.4)
    card_bottom = int(h * 0.93)
    card_box = [card_margin_x, card_top, w - card_margin_x, card_bottom]
    card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle(card_box, radius=28 * scale, fill=(255, 255, 255, 70))
    card = card.filter(ImageFilter.GaussianBlur(radius=2 * scale))
    img = Image.alpha_composite(img, card)

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(card_box, radius=28 * scale, outline=(255, 255, 255, 90), width=max(1, scale))

    # Center double chevron ">>" drawn with lines (no text/font)
    chev_color = (255, 255, 255, 210)
    chev_size = 30 * scale
    chev_thick = max(2, 5 * scale)
    center_y = (card_top + card_bottom) / 2
    gap = 16 * scale
    draw_chevron(draw, w / 2 - gap / 2, center_y, chev_size, chev_thick, chev_color)
    draw_chevron(draw, w / 2 + gap / 2, center_y, chev_size, chev_thick, chev_color)

    img = img.convert("RGB")
    suffix = "@2x" if scale == 2 else ""
    path = os.path.join(OUT_DIR, f"dmg_background{suffix}.png")
    img.save(path, "PNG")
    print("wrote", path)


if __name__ == "__main__":
    render(1)
    render(2)
