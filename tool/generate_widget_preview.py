#!/usr/bin/env python3
"""Renders the Manga Deck widget picker preview.

The launcher shows `android:previewImage` in the widget picker, so it has to be
a static picture of the deck. This draws the same 4-card cascade the real
StackView produces (84x116dp covers, 20dp corners, spread across the leftover
width) with abstract cover art, so the preview never depends on the reader's
own library.

Run from the repo root:  python3 tool/generate_widget_preview.py
"""

from PIL import Image, ImageDraw, ImageFilter

SIZE = 192
CARD_W, CARD_H = 84, 116
RADIUS = 20
STEP_X, STEP_Y = 32, 20
MARGIN = 6

# Front card sits bottom-left, the rest cascade up and to the right.
COLORS = [
    ((36, 46, 78), (76, 141, 255)),    # accent blue
    ((48, 26, 58), (168, 85, 247)),    # violet
    ((22, 48, 46), (45, 190, 170)),    # teal
    ((58, 34, 22), (245, 158, 66)),    # amber
]


def gradient(width, height, top, bottom):
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / max(1, height - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (width, y)], fill=color)
    return img


def rounded_mask(width, height, radius):
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (width - 1, height - 1)], radius=radius, fill=255
    )
    return mask


def card(top, bottom):
    img = gradient(CARD_W, CARD_H, top, bottom)

    # Soft highlight in the upper half, like a glossy cover.
    glow = Image.new("L", (CARD_W, CARD_H), 0)
    ImageDraw.Draw(glow).ellipse(
        [CARD_W * 0.15, -CARD_H * 0.25, CARD_W * 0.95, CARD_H * 0.55], fill=70
    )
    glow = glow.filter(ImageFilter.GaussianBlur(12))
    img = Image.composite(Image.new("RGB", img.size, (255, 255, 255)), img, glow)

    draw = ImageDraw.Draw(img, "RGBA")
    # Title block and a couple of text lines: enough to read as a manga cover.
    draw.rounded_rectangle(
        [10, 14, CARD_W - 10, 32], radius=4, fill=(255, 255, 255, 220)
    )
    for i, y in enumerate((46, 56, 66)):
        draw.rounded_rectangle(
            [10, y, CARD_W - 10 - i * 14, y + 4], radius=2, fill=(255, 255, 255, 90)
        )
    # Bottom band, like a publisher strip.
    draw.rectangle([0, CARD_H - 18, CARD_W, CARD_H], fill=(0, 0, 0, 60))

    img.putalpha(rounded_mask(CARD_W, CARD_H, RADIUS))
    return img


def main():
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # Back to front so the front-most card ends up on top.
    for i in reversed(range(4)):
        top, bottom = COLORS[i]
        x = MARGIN + i * STEP_X
        y = SIZE - MARGIN - CARD_H - i * STEP_Y
        layer = card(top, bottom)

        # Hairline outline keeps overlapping cards readable on light and dark
        # picker backgrounds.
        outline = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        ImageDraw.Draw(outline).rounded_rectangle(
            [(0, 0), (CARD_W - 1, CARD_H - 1)],
            radius=RADIUS,
            outline=(0, 0, 0, 60),
            width=1,
        )
        layer = Image.alpha_composite(layer, outline)
        canvas.alpha_composite(layer, (x, y))

    out = "android/app/src/main/res/drawable-nodpi/ic_appwidget_recent.png"
    canvas.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
