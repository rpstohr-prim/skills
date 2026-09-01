#!/usr/bin/env python3
"""
Scene-still builder for training videos.

Every still is 1920x1080 and obeys two constraints that come from the video API
rather than from taste:

  CENTRE-CROP. Scenes are whole-frame and cropped to the output canvas, so a
  raw screenshot placed directly loses its top and bottom rows. Compositing onto
  a full-size canvas first is what stops that.

  CAPTION BAND. Burned-in captions land in the bottom band. The image area stops
  at CAPTION_TOP and the band below is left empty, so captions sit on canvas
  instead of over the content.

Set PALETTE from the colours sampled out of the source document — the defaults
here are neutral placeholders, not anybody's brand.

Usage:

    from framelib import frame, card, set_palette

    set_palette(brand="#00A3D6", deep="#007BB6", accent="#5148FE")

    frame("out.png", "screenshot.png",
          kicker="READING THE COUNTS",
          label="This column counts UNRESOLVED items only.",
          cite="User Guide p.15",
          zoom=(0, 215, 946, 240),      # crop to a region, in SOURCE pixels
          box=(688, 236, 96, 16))       # highlight, in SOURCE pixels
"""

import pymupdf

W, H = 1920, 1080
CAPTION_TOP = 900          # below this is reserved for burned-in captions

PALETTE = {
    "brand": "#00A3D6",    # kickers, accents — from the DOCUMENT
    "deep": "#007BB6",     # left spine, avatar background
    "body": "#000000",
    "grey": "#7F7F7F",
    "rule": "#D9D9D9",
    "accent": "#5148FE",   # highlight boxes — from the APPLICATION UI
}


def set_palette(**kwargs):
    """Override any palette entry with a colour sampled from the source."""
    PALETTE.update(kwargs)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _page():
    doc = pymupdf.open()
    pg = doc.new_page(width=W, height=H)
    pg.draw_rect(pymupdf.Rect(0, 0, W, H), color=None, fill=(1, 1, 1))
    pg.draw_rect(pymupdf.Rect(0, 0, 26, H), color=None, fill=rgb(PALETTE["deep"]))
    return doc, pg


def _save(doc, pg, path):
    pg.get_pixmap(dpi=72).save(path)
    doc.close()
    return path


def frame(out, shot, kicker, label, cite, box=None, zoom=None, pad=24):
    """
    Place a screenshot under a kicker and a statement line.

    box  — (x, y, w, h) in SOURCE pixels. Drawn as a highlight.
    zoom — (x, y, w, h) in SOURCE pixels. Crop to this region first, which both
           highlights it and fixes legibility: guide screenshots are small
           originals and a full grid on a 1920 canvas is hard to read.

    Nothing animates inside a scene, so a highlight that follows the narration
    is a sequence of these — one per beat, each paired with one sentence.
    """
    doc, pg = _page()
    pg.insert_text((110, 92), kicker, fontname="hebo", fontsize=30,
                   color=rgb(PALETTE["brand"]))
    pg.insert_text((110, 152), label, fontname="hebo", fontsize=42,
                   color=rgb(PALETTE["body"]))

    src = pymupdf.Pixmap(shot)
    sw, sh = src.width, src.height

    if zoom:
        zx, zy, zw, zh = zoom
        zx, zy = max(0, zx - pad), max(0, zy - pad)
        zw, zh = min(sw - zx, zw + pad * 2), min(sh - zy, zh + pad * 2)
    else:
        zx, zy, zw, zh = 0, 0, sw, sh

    avail_w, avail_h = W - 220, CAPTION_TOP - 210
    scale = min(avail_w / zw, avail_h / zh)
    dw, dh = zw * scale, zh * scale
    dx, dy = 110 + (avail_w - dw) / 2, 200 + (avail_h - dh) / 2

    pg.draw_rect(pymupdf.Rect(dx - 3, dy - 3, dx + dw + 3, dy + dh + 3),
                 color=rgb(PALETTE["rule"]), width=3)

    if zoom:
        # insert_image has no clip argument, so crop the pixmap and place that.
        ir = pymupdf.IRect(int(zx), int(zy), int(zx + zw), int(zy + zh))
        cropped = pymupdf.Pixmap(src.colorspace, ir, src.alpha)
        cropped.copy(src, ir)
        tmp = out + ".crop.png"
        cropped.save(tmp)
        pg.insert_image(pymupdf.Rect(dx, dy, dx + dw, dy + dh), filename=tmp)
    else:
        pg.insert_image(pymupdf.Rect(dx, dy, dx + dw, dy + dh), filename=shot)

    if box:
        bx, by, bw, bh = box
        r = pymupdf.Rect(dx + (bx - zx) * scale, dy + (by - zy) * scale,
                         dx + (bx - zx + bw) * scale, dy + (by - zy + bh) * scale)
        # White halo under the accent stroke, so the box reads on both a pale
        # panel fill and a dark nav bar without picking a colour per screenshot.
        pg.draw_rect(r + (-3, -3, 3, 3), color=(1, 1, 1), width=6)
        pg.draw_rect(r, color=rgb(PALETTE["accent"]), width=3.5)

    pg.insert_text((110, CAPTION_TOP + 34), cite, fontname="helv", fontsize=22,
                   color=rgb(PALETTE["grey"]))
    return _save(doc, pg, out)


def card(out, kicker, lines, sub=None, bullets=None, boxes=None):
    """
    A built slide — title cards, and concept diagrams for material the guide
    states in prose or tables with no screenshot to show.

    boxes — list of (x, y, w, h, heading, subtext, fill) for contrast layouts.
            Two boxes side by side is the workhorse: it is how you show that
            two similar-looking actions have opposite consequences.
    """
    doc, pg = _page()
    pg.insert_text((110, 92), kicker, fontname="hebo", fontsize=30,
                   color=rgb(PALETTE["brand"]))
    y = 190
    for ln in lines:
        pg.insert_text((110, y), ln, fontname="hebo", fontsize=62,
                       color=rgb(PALETTE["body"]))
        y += 76
    if sub:
        pg.draw_line(pymupdf.Point(110, y), pymupdf.Point(700, y),
                     color=rgb(PALETTE["rule"]), width=3)
        pg.insert_text((110, y + 52), sub, fontname="helv", fontsize=30,
                       color=rgb(PALETTE["grey"]))
        y += 100
    for b in (bullets or []):
        pg.insert_text((110, y), b, fontname="helv", fontsize=34,
                       color=rgb(PALETTE["body"]))
        y += 54
    for (bx, by, bw, bh, t1, t2, fill) in (boxes or []):
        f = rgb(fill) if isinstance(fill, str) else fill
        pg.draw_rect(pymupdf.Rect(bx, by, bx + bw, by + bh), color=None, fill=f)
        pg.insert_text((bx + 28, by + 52), t1, fontname="hebo", fontsize=30,
                       color=(1, 1, 1))
        if t2:
            pg.insert_text((bx + 28, by + 96), t2, fontname="helv", fontsize=26,
                           color=(1, 1, 1))
    return _save(doc, pg, out)


def wpm_runtime(script_text, wpm=200):
    """
    Estimated seconds for a script.

    The default is 200, not the 140 instructional scripts are conventionally
    written to. Synthesised voices run nearer 200, and scripts written to 140
    land about 40% short. Treat this as a planning figure only — measure the
    rendered file and use that number wherever the runtime is quoted.
    """
    return len(script_text.split()) / wpm * 60
