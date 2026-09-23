#!/usr/bin/env python3
"""Render plain-text terminal output as a realistic terminal-window PNG.

Used to turn real command output (captured during the project) into
clear, readable screenshot-style figures for the report.
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

BG = (24, 26, 32)
BAR = (52, 55, 63)
FG = (232, 233, 235)
GREEN = (126, 231, 135)
CYAN = (110, 195, 240)
YELLOW = (245, 200, 100)
RED = (255, 123, 114)
GREY = (139, 148, 158)


def wrap_line(line, max_chars):
    if len(line) <= max_chars:
        return [line]
    out = []
    while line:
        cut = line[:max_chars]
        if len(line) > max_chars:
            sp = cut.rfind(" ")
            if sp > max_chars // 2:
                cut = cut[:sp]
        out.append(cut)
        line = line[len(cut):].lstrip()
    return out


def render(text_path, out_path, title, max_chars=96, font_size=21):
    with open(text_path) as fh:
        raw_lines = [l.rstrip("\n") for l in fh.readlines()]
    while raw_lines and not raw_lines[-1].strip():
        raw_lines.pop()

    lines = []
    for l in raw_lines:
        lines.extend(wrap_line(l, max_chars))

    font = ImageFont.truetype(FONT_PATH, font_size)
    bold = ImageFont.truetype(FONT_BOLD, font_size)
    lh = int(font_size * 1.42)
    pad = 26
    bar_h = 44
    win_w = pad * 2 + int(max_chars * font_size * 0.602) + 4
    win_h = bar_h + pad + len(lines) * lh + pad

    img = Image.new("RGB", (win_w, win_h), BG)
    d = ImageDraw.Draw(img)

    # title bar
    d.rectangle([0, 0, win_w, bar_h], fill=BAR)
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        x = 20 + i * 30
        d.ellipse([x, bar_h // 2 - 7, x + 14, bar_h // 2 + 7], fill=c)
    tw = d.textlength(title, font=font)
    d.text(((win_w - tw) // 2, (bar_h - font_size) // 2 - 2), title,
           font=font, fill=(200, 203, 208))

    y = bar_h + pad
    for line in lines:
        x = pad
        if line.startswith("$ "):
            d.text((x, y), "$ ", font=bold, fill=GREEN)
            w = d.textlength("$ ", font=bold)
            d.text((x + w, y), line[2:], font=bold, fill=(255, 255, 255))
        elif line.startswith("=== "):
            d.text((x, y), line, font=bold, fill=CYAN)
        else:
            # simple highlighting of common status words
            color = FG
            stripped = line.strip()
            if stripped.startswith(("ok", "✓", "✔")) or " pass " in f" {stripped} ":
                color = GREEN
            elif stripped.startswith(("not ok", "✗", "ERROR", "FAIL")):
                color = RED
            elif stripped.startswith(("#", "  ---", "  ...")):
                color = GREY
            d.text((x, y), line, font=font, fill=color)
        y += lh

    img.save(out_path)
    print(f"wrote {out_path} ({img.width}x{img.height})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("text_file")
    ap.add_argument("out_file")
    ap.add_argument("--title", default="Terminal")
    ap.add_argument("--width", type=int, default=96)
    ap.add_argument("--font-size", type=int, default=21)
    a = ap.parse_args()
    os.makedirs(os.path.dirname(a.out_file), exist_ok=True)
    render(a.text_file, a.out_file, a.title, a.width, a.font_size)
