---
name: fts-press-release
description: >-
  Publish a FinTech Studios press release on the marketing site
  (www.fintechstudios.com/press, repo Fintech-Studios-Apps/FTS-Marketing). Use
  when the user hands over a press release — an EIN Presswire / distribution
  email (.html), a PDF, a Word doc, pasted text or a wire link — and wants it
  "added to the website", "put on the press page", "posted to the marketing
  site" or "published on fintechstudios.com". Also use when editing or fixing an
  existing entry in pressReleases.ts, or when a press page renders wrongly
  (missing list numbers, URLs not clickable, lines running together).
metadata:
  version: 1.0.0
---

# Publish a press release on fintechstudios.com

Press releases are static data. Each one is an object in
`src/lib/data/pressReleases.ts`, rendered at `/press/<slug>` by
`src/app/(marketing)/press/[slug]/page.tsx` and listed on `/press`. Merging to
`main` deploys the site on Vercel automatically. No database, no CMS.

| | |
|---|---|
| Repo | `Fintech-Studios-Apps/FTS-Marketing` (Next.js, Vercel) |
| Local checkout | `~/Documents/Projects/FTS Web/FTS-Marketing` (keep on `main`) |
| Worktree | `../FTS-Marketing-<label>` beside it, branch `feature/<label>` from `origin/main` |
| Data file | `src/lib/data/pressReleases.ts` |
| Live URL | `https://www.fintechstudios.com/press/<slug>` |

## Ground rules

- **The release's words are the content.** Copy headline, deck, body, quotes,
  About text and dates verbatim. Don't tighten, re-punctuate or "fix" claims —
  the site must match the wire version. Restructure only (see the format
  reference); flag anything that looks wrong to the user instead of editing it.
- **Drop the email chrome**: preheader, "View online", masthead/footer, share
  buttons, and a pull quote that repeats part of a full quote below it.
- **Newest goes first.** The press list renders in array order (no sort), so the
  new object goes at the top of `pressReleases`.
- **Marketing repo only.** CLAUDE.md says to mirror press releases into FTS-Web;
  that is stale — FTS-Web has not carried the recent releases. Don't touch it.
- **Merge only with approval.** Open the PR, share the Vercel preview, and merge
  when the user approves (or already said to merge in the request).

## Steps

1. **Read the source in full.** For HTML email, read the file; for a PDF use the
   pdf skill. Note headline, deck/subhead, date, dateline city, quotes and their
   attributions, sections, links, media contact.
2. **Worktree**: `git fetch origin && git worktree add "../FTS-Marketing-<label>"
   -b feature/<label> origin/main`; confirm with `git branch --show-current`.
3. **Read the top entry** of `pressReleases.ts` to match the current style, then
   write the new entry following [references/format.md](references/format.md).
4. **Verify**: `npm ci`, `npx tsc --noEmit -p .`, `npx eslint
   src/lib/data/pressReleases.ts`, `npm run build` (the output must list
   `/press/<slug>`). Then `npx next start -p 4317` and look at the page in the
   browser at phone width: headings, bullets, blockquotes, code, no run-on lines.
   Stop the server after.
5. **Ship**: commit (`feat(press): add <short title> press release`), push, `gh pr
   create`. `gh pr checks <n> --watch` until Vercel passes; the preview URL is in
   the Vercel bot comment (`gh pr view <n> --json comments`). Give the user the PR
   and `<preview>/press/<slug>`.
6. **On approval**: `gh pr merge <n> --squash`. The "'main' is already used by
   worktree" error is local only — confirm with `gh pr view <n> --json state`.
   Wait for the merge commit's status to be `success`
   (`gh api repos/Fintech-Studios-Apps/FTS-Marketing/commits/<sha>/status --jq
   .state`), then `curl -s -o /dev/null -w "%{http_code}"
   https://www.fintechstudios.com/press/<slug>` should be 200.
7. **Clean up**: remove the worktree, delete the local and remote branch.

## Report back

Live URL, PR link, and a short list of every place the page differs from the
source (dropped pieces, restructured lists, wording changes forced by
formatting), plus anything you noticed but deliberately left verbatim (a
grammatical slip in the headline, a stale address).
