---
name: training-video-from-guide
description: "Turn a PDF user guide, manual, SOP or training document into produced narrated training videos using the HeyGen MCP connector. Use this whenever the user wants to make training videos, explainer videos, onboarding videos or screen-walkthrough videos from a document — and also when they hand over a product manual, user guide or procedure PDF and ask to 'make training from this', 'record segments', 'turn this into videos', 'build a curriculum', or ask how long producing training from a guide would take. Covers extracting screenshots and the client's own palette from the PDF, re-cutting the document into task-shaped segments, writing narration that lands at the right runtime, framing stills so nothing is cropped or covered by captions, highlighting the exact field being narrated, and driving HeyGen end to end."
metadata:
  version: 1.0.0
---

# Training videos from a PDF guide

A user guide already contains everything a training video needs — the procedures,
the screenshots, the brand palette, the vocabulary the audience uses. The work is
re-shaping it, because a manual is organised for *lookup* and a video has to be
organised for *learning*.

This skill covers the whole path: PDF in, rendered MP4s out.

## Before anything else: two questions about the source

Ask these early. Both are cheap to answer at the start and expensive to discover
at the end.

**May we distribute derivatives of this document?** Manuals are routinely marked
proprietary or confidential. Producing videos from one is a derivative
distribution, not an internal read. Get an explicit yes rather than inferring it
from the fact that someone handed you the file.

**Is the sample data real?** Screenshots in user guides often show plausible
account numbers, names and amounts. Usually it is constructed test data; not
always. A named individual's financial record on a training video is not a thing
to assume your way past. Ask, and record the answer.

## 1. Extract

Use `scripts/extract_guide.py`. It pulls the table of contents, per-page text,
and the content screenshots.

```bash
python scripts/extract_guide.py guide.pdf --out ./work
```

Two things it does that a naive extraction does not:

**Filters page furniture.** Headers, footers and sidebar rules are embedded
images that repeat on every page. The script drops any image appearing on more
than three pages, plus anything below an icon-sized threshold. On a 54-page guide
this took 100 raw images down to 21 real screenshots.

**Keeps the page number.** Every screenshot is named for the page it came from,
which is what lets you cite the source later.

If PyMuPDF is not installed, `pip install pymupdf`. Reach for that before
`poppler`/`pdftotext` — it is one dependency, needs no system packages, and does
text, images and rendering in the same library.

### Verify before you label

Look at each extracted screenshot and confirm what it actually shows before you
name it. Page-order inference is usually right and occasionally wrong, and a
mislabelled asset propagates into the script, the video and the citation. This
costs a couple of minutes and removes an entire class of embarrassing error.

## 2. Take the palette from the document

Do not guess brand colours, and do not use your own. Sample them:

- **Vector fills and text colours** — `page.get_drawings()` and
  `page.get_text("dict")` give the exact heading, link and rule colours.
- **Screenshot pixels** — the application's own chrome. Count dominant colours
  across a UI screenshot to get the real nav bar, panel and accent values.

You usually end up with two palettes: the *document* brand (headings, links) and
the *application* UI (nav, panels, accents). Use the document palette for titles
and framing, and the application palette for anything annotating a screenshot, so
your callout never competes with the UI it is pointing at.

## 3. Re-cut by task, not by screen

This is the judgement call the whole thing turns on.

Manuals are organised by screen, with an exhaustive field table after each
procedure. That is right for lookup and wrong for learning: a new person cannot
tell from the contents page what they need on day one.

Re-cut into segments by **task**, in the order someone actually meets them.
Expect to depart from document order, and say why in writing each time. Common
departures worth making:

- **Pull the daily actions forward** out of whatever chapter they happen to sit
  in. Manuals often introduce a common action inside a specialist chapter.
- **Split actions that look alike and behave differently.** If two operations
  share a screen and a click count but have opposite consequences, they are two
  segments. Merging them is how someone does the irreversible one by accident.
- **Demote the field tables to reference appendices.** Nobody learns a 40-row
  table; they consult it. Attach it to the segment whose screen it describes.

Tier the segments — foundation / core / efficiency / situational / oversight —
and produce video for the core tier first. Six well-made core videos beat twelve
thin ones, and the tiering tells the client why you stopped where you did.

**Name the gaps out loud.** Segments with a procedure but no video should stay in
the catalogue, and the agent or the docs should say plainly that they are not
recorded yet. A named gap reads as a curriculum; a hidden one reads as a demo
prop.

## 4. Write narration to ~200 words per minute

The most useful number in this skill.

Instructional scripts are conventionally written to 140 wpm, which is a human
presenter's pace. Synthesised voices run nearer **200**. Scripts written to 140
land about 40% short — a "4:12" script renders at 2:21.

So: **write to 200 wpm**, or write to 140 and set `voice_settings.speed` to
0.85–0.9 at render. Do not do both.

Then measure the rendered file and use *that* number anywhere the runtime is
quoted. If an agent tells a user "this is two and a half minutes" and then waits,
a wrong number is the first thing the room notices.

### What makes the narration worth listening to

The guide states facts. The video should state facts **and their consequences** —
that is the whole reason a video beats the manual.

Look for these while reading, because they are the moments people remember:

- **Conventions that are counterintuitive.** An age counter that starts at 1
  meaning "yesterday" is a whole beat on its own.
- **Controls the audience must not use.** Manuals often document a button and
  then note, pages later, that it does not apply to most readers.
- **Facts stated pages apart that are only dangerous together.** "Select all
  takes the current page" on p.20 and "we recommend 20 rows" on p.27 are
  individually harmless. Put them in one scene.
- **Where the guide is silent.** If the manual documents each field but never
  gives the rule for choosing between them, say so. Do not fill the gap.

## 5. Frame every still — the API centre-crops

Read `references/heygen.md` for the API sequence. Two constraints shape every
still you make:

**Scenes are whole-frame and centre-cropped to the output canvas.** A 803×548
screenshot cropped to 16:9 loses its top and bottom rows — which on a data grid
is the content. So composite every screenshot onto a 1920×1080 canvas first.

**Captions burn into the bottom band.** Leave it empty. `scripts/framelib.py`
stops the image area at y=900 and leaves the band below clear, so captions land
on canvas rather than over the data.

Framing also earns its keep by carrying the on-screen text: a kicker, a statement
line, and the source citation, burned into the still. Without it those live only
in your script document and never reach the viewer.

## 6. Highlighting is one still per beat

Nothing animates inside a scene. A highlight that appears to follow the narration
is really a sequence of stills, each pre-rendered with the box already drawn, each
paired with one sentence.

`framelib.frame()` takes `box=(x, y, w, h)` in source-image pixels, and
`zoom=(x, y, w, h)` to crop to a region first.

**Prefer zoom-and-box over box alone for detail beats.** Guide screenshots are
small originals shown on a large canvas, so a full-frame view of a field grid is
hard to read. Zooming to the region both highlights it and fixes legibility. Keep
full-frame for orientation beats where the point is *where* a thing sits.

Getting box coordinates is an iterate-and-check loop: read the screenshot's
dimensions, estimate the region, render, look at it, adjust. Budget for it — it
is the most time-consuming part of the whole process, roughly an hour per video.

## 7. Structure and render

A shape that works:

1. **Title card** — narrated, one line
2. **Avatar** — the framing sentence, on a brand-colour background
3. **Content stills** — one per beat, narrated
4. **Avatar** — the closing line and what comes next

The avatar bookends rather than sitting over the screen work, because the API has
no picture-in-picture. Use **one voice throughout** — the avatar's own default is
the safe pick — so the narration does not change voice when the picture does.

Set `caption: { file_format: "srt", style: "default" }`. HeyGen returns *both* a
clean `video_url` and a separate `captioned_video_url` from the same render, so
enabling captions costs nothing and gives you the choice later.

## 8. Do not put the MP4s in git

Six videos at ~6MB each is 40MB that version control carries forever. Put them in
object storage and serve them from there.

If the videos are already committed on an unpushed branch, squash before pushing
— the blobs then never reach the remote at all. After pushing, the only fix is a
history rewrite on a shared branch.

**HeyGen's own URLs are not a hosting option.** They are presigned and expire
seven days after render, so a hardcoded link works right through testing and
fails later, most likely in front of someone.

## Deliverables

Alongside the MP4s, hand over:

- **A segment breakdown** — the re-cut, with the departures from document order
  and why each was made
- **Scripts with scene tables** — timing, asset, on-screen text, narration
- **The extracted assets**, named for what they show
- **The sampled palette**, so later work matches
- **Measured runtimes**, recorded wherever they are quoted
