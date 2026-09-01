#!/usr/bin/env python3
"""
Extract a PDF user guide into the parts a training video needs.

    python extract_guide.py guide.pdf --out ./work

Produces:
    work/toc.txt          table of contents with page numbers
    work/guide.txt        per-page text, page-delimited
    work/palette.txt      colours sampled from the document itself
    work/assets/          content screenshots, named p<NN>_<w>x<h>.png

The filtering is the point. A naive image extraction on a 54-page guide returns
~100 images, most of which are the header bar and sidebar rule repeated on every
page. Two rules cut that to the real screenshots:

  - an image appearing on more than `--max-pages` pages is page furniture
  - an image below `--min-width`/`--min-height` is an icon

Page numbers are kept in the filename because they become the citation on screen.
"""

import argparse
import collections
import os
import sys

try:
    import pymupdf
except ImportError:
    sys.exit("PyMuPDF is required:  pip install pymupdf")


def hexcolor(c):
    if c is None:
        return None
    return "#%02X%02X%02X" % tuple(int(round(v * 255)) for v in c[:3])


def extract(pdf_path, out_dir, max_pages, min_w, min_h):
    doc = pymupdf.open(pdf_path)
    assets = os.path.join(out_dir, "assets")
    os.makedirs(assets, exist_ok=True)

    with open(os.path.join(out_dir, "toc.txt"), "w") as f:
        toc = doc.get_toc()
        if not toc:
            f.write("(no embedded table of contents)\n")
        for level, title, page in toc:
            f.write(f"{'  ' * (level - 1)}{page:>4}  {title}\n")

    with open(os.path.join(out_dir, "guide.txt"), "w") as f:
        for i, page in enumerate(doc, start=1):
            f.write(f"\n\n=========== PAGE {i} ===========\n")
            f.write(page.get_text())

    # Colours the document uses on itself — headings, links, rules. These are the
    # brand palette, and sampling beats guessing.
    fills = collections.Counter()
    texts = collections.Counter()
    for page in doc:
        for drawing in page.get_drawings():
            for key in ("fill", "color"):
                h = hexcolor(drawing.get(key))
                if h:
                    fills[h] += 1
        for block in page.get_text("dict")["blocks"]:
            for line in block.get("lines", []):
                for span in line["spans"]:
                    texts["#%06X" % span["color"]] += len(span["text"])
    with open(os.path.join(out_dir, "palette.txt"), "w") as f:
        f.write("Vector fills and strokes (most common first)\n")
        for h, n in fills.most_common(12):
            f.write(f"  {h}  {n}\n")
        f.write("\nText colours, weighted by characters set\n")
        for h, n in texts.most_common(12):
            f.write(f"  {h}  {n}\n")
        f.write("\nSample the APPLICATION palette separately, from a UI\n")
        f.write("screenshot's dominant pixel colours — it differs from the\n")
        f.write("document's own brand and both get used.\n")

    freq = collections.Counter()
    first_page = {}
    for i, page in enumerate(doc, start=1):
        for img in page.get_images(full=True):
            xref = img[0]
            freq[xref] += 1
            first_page.setdefault(xref, i)

    kept = []
    for xref, count in freq.items():
        if count > max_pages:
            continue                      # header, footer, sidebar rule
        try:
            pix = pymupdf.Pixmap(doc, xref)
        except Exception:
            continue
        if pix.width < min_w or pix.height < min_h:
            continue                      # icon or bullet
        if pix.n - pix.alpha > 3:
            pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
        page = first_page[xref]
        # The xref is in the name because several distinct images can share a
        # page and a size — cover art especially. Without it they collide and
        # silently overwrite each other, and you lose assets without noticing.
        name = f"p{page:02d}_x{xref}_{pix.width}x{pix.height}.png"
        pix.save(os.path.join(assets, name))
        kept.append((page, name))

    kept.sort()
    print(f"pages       {doc.page_count}")
    print(f"screenshots {len(kept)}  (from {len(freq)} raw images)")
    for page, name in kept:
        print(f"  p{page:<4} {name}")
    print(f"\nLook at each one and confirm what it shows before you name it.")
    print(f"Page-order inference is usually right and occasionally wrong.")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pdf")
    ap.add_argument("--out", default="./work")
    ap.add_argument("--max-pages", type=int, default=3,
                    help="an image on more pages than this is page furniture")
    ap.add_argument("--min-width", type=int, default=300)
    ap.add_argument("--min-height", type=int, default=180)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    extract(args.pdf, args.out, args.max_pages, args.min_width, args.min_height)


if __name__ == "__main__":
    main()
