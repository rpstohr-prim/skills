# Driving HeyGen

The MCP connector surface, in the order you actually use it, plus the things
that cost time to discover.

## Contents

- [Check the account first](#check-the-account-first)
- [Pick an avatar and one voice](#pick-an-avatar-and-one-voice)
- [Upload the stills](#upload-the-stills)
- [Create the video](#create-the-video)
- [Poll, then download](#poll-then-download)
- [Constraints worth knowing before you design](#constraints-worth-knowing-before-you-design)

## Check the account first

`get_current_user` returns the plan and the remaining credits. Do this before
building 30 stills, not after.

## Pick an avatar and one voice

`list_avatar_looks` with `avatarType: "studio_avatar"`, `ownership: "public"`.
Each look carries a `default_voice_id` and a `preferred_orientation` — prefer a
landscape look for 16:9.

Use **one voice for the whole video**, including the narration over stills. The
avatar's own `default_voice_id` is the safe pick because compatibility is
guaranteed. A different voice on the screen scenes makes the narration appear to
change speaker every time the picture changes.

`list_voices` is there if you want to choose deliberately, but check the voice is
compatible with the avatar's engine before committing.

## Upload the stills

Three steps, and the middle one is a plain HTTP PUT rather than an MCP call.

1. `create_asset_upload_batch` with `files: [{filename, content_type, size_bytes}]`
   — up to 100. Returns a `batch_id` and one slot per file with an `asset_id` and
   a presigned `upload_url`.
2. `PUT` each file's bytes to its `upload_url` with headers
   `content-type: image/png` and `x-amz-server-side-encryption: AES256`.
   The byte size is signed into the URL, so it must match exactly.
3. `complete_asset_batch` with the `batch_id`.

`get_asset_batch` shows per-item progress. Items sit in `processing` briefly;
that is fine, video creation can follow immediately.

## Create the video

`create_video_from_studio` takes an ordered list of whole-frame scenes.

```
{
  aspectRatio: "16:9",
  resolution: "1080p",
  caption: { file_format: "srt", style: "default" },
  scenes: [ ... ]
}
```

Two scene types matter:

**`avatar_video`** — an avatar speaking, on a solid colour background.

```
{ type: "avatar_video",
  input: { type: "avatar",
           avatar_id: "...", voice_id: "...",
           engine: { type: "avatar_iii" },
           background: { type: "color", color: "#007BB6" },
           script: "..." } }
```

**`image`** — a still, narrated.

```
{ type: "image",
  source: { type: "asset_id", asset_id: "..." },
  voice_id: "...",
  script: "..." }
```

Scene duration is derived from the audio; you do not set it. An `image` scene can
alternatively take `duration` for a silent hold, but not both.

Check `supported_api_engines` on the avatar look before setting `engine` — not
every look supports every engine.

## Poll, then download

`bulk_video_statuses` takes comma-separated ids and is the cheap way to watch
several at once. A 2–3 minute video takes roughly 4–6 minutes to render.

`get_video` then returns:

- `video_url` — the clean render
- `captioned_video_url` — **the same render with captions burned in**, produced
  automatically when `caption.style` is set
- `subtitle_url` — the SRT sidecar
- `duration` — the real runtime, in seconds

Both video files come from one render at no extra cost, so enabling captions
gives you the choice rather than committing you.

Download promptly and host the files yourself.

## Constraints worth knowing before you design

**No picture-in-picture.** Scenes are whole-frame. An avatar inset over a
screenshot is not available, so the avatar bookends instead — opening and
closing — and the screen work runs full-frame with voiceover.

**Every scene is centre-cropped to the canvas.** Composite screenshots onto a
full-size canvas before uploading, or they lose their edges.

**Nothing animates inside a scene.** A highlight that follows the narration is a
sequence of stills, one per beat.

**Captions burn into the bottom band.** Leave it empty when framing.

**`video_url` expires in seven days.** It is a presigned CloudFront link. Never
hardcode one — it works right through testing and then fails. Download and serve
from your own storage.

**Runtimes come in short if you wrote to 140 wpm.** The voice runs nearer 200.
Either write to 200, or set `voice_settings: { speed: 0.85 }` — not both.
