"""Renders the Alright! launcher icons: the tilted blue "alright!" panel on ink.

Geometry follows lib/shared/brand_wordmark.dart (padding 22/6/22/10 and
radius 6 at font size 42, letter spacing -1.2, tilt -0.07 rad).

    python3 tool/make_icons.py . [preview.png]
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = sys.argv[1]
INK = (10, 10, 10, 255)
BLUE = (13, 17, 212, 255)
WHITE = (255, 255, 255, 255)

SIZE = 400  # master font size
UNIT = SIZE / 42
FONT = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/Inter-800.ttf'), SIZE)
TEXT = 'alright!'


def panel(knockout=False):
    """The tilted panel on transparency. With knockout, the letters are holes
    (for Android's monochrome themed icon)."""
    spacing = -1.2 * UNIT
    advances = [FONT.getlength(c) + spacing for c in TEXT]
    text_w = sum(advances) - spacing
    ascent, descent = FONT.getmetrics()
    pl, pt, pr, pb = 22 * UNIT, 6 * UNIT, 22 * UNIT, 10 * UNIT
    w, h = int(text_w + pl + pr), int(ascent + descent + pt + pb)

    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=6 * UNIT,
                        fill=WHITE if knockout else BLUE)
    x = pl
    for c, adv in zip(TEXT, advances):
        d.text((x, pt), c, font=FONT, anchor='la',
               fill=(0, 0, 0, 0) if knockout else WHITE)
        x += adv
    if knockout:
        # ImageDraw blends, so punch the letters out through the alpha.
        mask = Image.new('L', (w, h), 0)
        md = ImageDraw.Draw(mask)
        x = pl
        for c, adv in zip(TEXT, advances):
            md.text((x, pt), c, font=FONT, anchor='la', fill=255)
            x += adv
        alpha = img.getchannel('A')
        alpha.paste(0, mask=mask)
        img.putalpha(alpha)
    # Flutter's -0.07 rad is anticlockwise on screen; PIL's positive is too.
    return img.rotate(math.degrees(0.07), resample=Image.BICUBIC, expand=True)


PANEL = panel()
PANEL_KNOCKOUT = panel(knockout=True)


def compose(px, width_share, background, art=PANEL):
    canvas = Image.new('RGBA', (px, px), background)
    target_w = round(px * width_share)
    scale = target_w / art.width
    art = art.resize((target_w, round(art.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(art, ((px - art.width) // 2, (px - art.height) // 2))
    return canvas


def rounded(img, radius_share):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.width - 1, img.height - 1),
        radius=round(img.width * radius_share), fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, mask=mask)
    return out


res = os.path.join(ROOT, 'android/app/src/main/res')
densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for name, k in densities.items():
    folder = os.path.join(res, f'mipmap-{name}')
    # Pre-Android 8 launchers: a rounded square.
    rounded(compose(round(48 * k), 0.80, INK), 0.2).save(
        os.path.join(folder, 'ic_launcher.png'))
    # Adaptive layers are 108 dp; the panel's corners stay inside the 66 dp
    # safe circle every mask shape keeps.
    fg = round(108 * k)
    compose(fg, 0.56, (0, 0, 0, 0)).save(
        os.path.join(folder, 'ic_launcher_foreground.png'))
    compose(fg, 0.56, (0, 0, 0, 0), PANEL_KNOCKOUT).save(
        os.path.join(folder, 'ic_launcher_monochrome.png'))

ios = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
with open(os.path.join(ios, 'Contents.json')) as f:
    images = json.load(f)['images']
for entry in images:
    side = float(entry['size'].split('x')[0])
    px = round(side * int(entry['scale'][0]))
    # iOS rounds the corners itself and rejects transparency.
    compose(px, 0.80, INK).convert('RGB').save(
        os.path.join(ios, entry['filename']))

if len(sys.argv) > 2:  # a preview of the full icon
    compose(1024, 0.80, INK).convert('RGB').save(sys.argv[2])
print('done')
