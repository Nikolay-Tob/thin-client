#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Генератор баннера загрузочной заставки (логотип + описание компании).

  python3 make-banner.py [--logo logo.png] [--text text.txt] [--out banner.png]

text.txt: первая строка — название (крупно), остальные — описание (мельче).
Тёмный логотип по умолчанию инвертируется (жёлтый остаётся), --style plate кладёт его на светлую плашку. Готовый banner.png положите на флешку в папку branding/ (раздел KIOSKBOOT) — он будет показан вместо встроенного.
Нужен Pillow (pip install pillow). Можно сделать баннер и в любом графическом редакторе: PNG с прозрачным фоном,
ширина до 1000 пикселей, светлый текст (фон заставки тёмный).
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

DEFAULT_TEXT = ("ООО ИК «СибИнТек»\n"
                "ИТ-интегратор ПАО «НК «Роснефть»\n"
                "Рабочее место на базе тонкого клиента")
FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf", "C:/Windows/Fonts/segoeui%s.ttf",
         "/usr/share/fonts/truetype/noto/NotoSans-%s.ttf", "/Library/Fonts/Arial%s.ttf"]


def font(size, bold=False):
    for pat in FONTS:
        for suf in (("-Bold", "b", "Bold") if bold else ("", "", "Regular")):
            p = pat % suf if "%s" in pat else pat
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def invert_logo(src, accent=(246, 206, 69)):
    """Dark logo on white paper -> light logo on a transparent background; yellow parts keep their colour."""
    src = src.convert("RGB")
    w, h = src.size
    out = Image.new("RGBA", (w, h))
    px, po = src.load(), out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            mn, mx = min(r, g, b), max(r, g, b)
            a, sat = 1 - mn / 255, (mx - mn) / 255
            if sat > 0.4:                                   # yellow: full colour, the white-paper edge fades out
                po[x, y] = accent + (round(255 * min(1, a * 2.2)),)
            else:                                           # black/grey -> white, slightly bolder
                po[x, y] = (255, 255, 255, round(255 * min(1, a ** 0.75 * 1.1)))
    return out


def make(logo, text, placeholder=False, height=170, style="invert"):
    """Logo on a light rounded plate on the left (usual logos are dark), the description on the right."""
    lines = [l.rstrip() for l in text.splitlines() if l.strip()]
    title, rest = lines[0], lines[1:]
    f1, f2 = font(30, True), font(21)
    pad, gap = 12, 26
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    plate = None
    if logo and style == "invert":
        lg = invert_logo(logo)
        lg = lg.resize((max(1, round(lg.width * (height - 8) / lg.height)), height - 8), Image.LANCZOS)
        plate = Image.new("RGBA", (lg.width, height), (0, 0, 0, 0))
        plate.paste(lg, (0, 4), lg)
    elif logo:
        lg = logo.convert("RGBA")
        inner = height - 48                      # white margin around the logo
        lg = lg.resize((max(1, round(lg.width * inner / lg.height)), inner), Image.LANCZOS)
        plate = Image.new("RGBA", (lg.width + 48, height), (255, 255, 255, 255))
        plate.alpha_composite(lg, (24, 24))
        mask = Image.new("L", plate.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, plate.width - 1, plate.height - 1), radius=14, fill=255)
        plate.putalpha(mask)
    elif placeholder:
        plate = Image.new("RGBA", (height, height), (0, 0, 0, 0))
        d = ImageDraw.Draw(plate)
        for i in range(0, height, 14):
            for xy in ((i, 1, min(i + 7, height - 1), 1), (i, height - 2, min(i + 7, height - 1), height - 2),
                       (1, i, 1, min(i + 7, height - 1)), (height - 2, i, height - 2, min(i + 7, height - 1))):
                d.line(xy, fill=(255, 255, 255, 150), width=2)
        tw = d.textlength("ЛОГОТИП", font=f2)
        d.text(((height - tw) / 2, height / 2 - 14), "ЛОГОТИП", font=f2, fill=(255, 255, 255, 190))
    text_h = 46 + len(rest) * 28
    text_w = max([probe.textlength(title, font=f1)] + [probe.textlength(l, font=f2) for l in rest])
    x0 = pad + (plate.width + gap if plate else 0)
    w = int(x0 + text_w + pad)
    h = (plate.height if plate else text_h) + 2 * pad
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if plate:
        img.paste(plate, (pad, pad), plate)
        d.line((pad + plate.width + gap // 2, pad + 14, pad + plate.width + gap // 2, h - pad - 14), fill=(246, 206, 69, 255), width=3)
    ty = (h - text_h) // 2
    d.text((x0, ty), title, font=f1, fill=(255, 255, 255, 255))
    for i, l in enumerate(rest):
        d.text((x0, ty + 46 + i * 28), l, font=f2, fill=(205, 210, 218, 255))
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--logo")
    ap.add_argument("--text")
    ap.add_argument("--style", choices=("invert", "plate"), default="invert",
                    help="invert: light logo on the dark background (yellow kept); plate: original logo on a white plate")
    ap.add_argument("--out", default="banner.png")
    ap.add_argument("--placeholder", action="store_true", help="draw an empty frame where the logo goes (preview)")
    a = ap.parse_args()
    text = open(a.text, encoding="utf-8").read() if a.text else DEFAULT_TEXT
    logo = Image.open(a.logo) if a.logo else None
    make(logo, text, a.placeholder, style=a.style).save(a.out)
    print("saved", a.out)


if __name__ == "__main__":
    sys.exit(main())
