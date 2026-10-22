# Press release entry format

## The object

```ts
{
  slug: "mcp-connector-1-1",          // kebab-case, short, product-led; must be unique
  title: "<headline, verbatim>",      // full wire headline
  shortTitle: "MCP Connector 1.1",    // 2–6 words, used in cards and the browser tab
  category: "Press Release",          // or "Awards" | "Press Coverage"
  date: "October 22, 2026",           // "Month D, YYYY"
  image: aiImage,                     // one of the image constants at the top of the file
  summary: "<deck / subhead, verbatim>",
  content: `<markdown body>`,
},
```

Pick `image` from the constants at the top of the file (`aiImage`,
`regulatoryImage`, `partnershipImage`, `chartImage`, `studioScreenshot`, ...).
Only add a new file under `public/images/press/` if the user supplies one.

`content` is a template literal: escape backticks as `` \` `` and any `${` as
`\${`.

## How the body renders (and what that forces)

The page renders `content` with `react-markdown` **without remark-gfm**, inside
`prose prose-invert`. So:

| Markdown | Result | Do this |
|---|---|---|
| Bare URL `https://...` | Plain text, not a link | `[text](url)` for pages; backticks for endpoints people paste (e.g. `` `https://mcp.fintechstudios.com/mcp` ``) |
| `1.` ordered list | Numbers are hidden; steps run together | Bold-label bullets: `- **Add the Connector**: ...` |
| Single newline | Lines merge into one paragraph | Blank line between every paragraph, bullet and contact line |
| Tables, strikethrough, task lists | Not rendered (GFM only) | Rewrite as bullets |
| `##`, `###`, `**bold**`, `*italic*`, `>` blockquote, `-` bullets | Fine | Use them |

Internal links are relative: `[www.fintechstudios.com/mcp](/mcp)`,
`[www.fintechstudios.com/contact](/contact)`.

## Body structure

Follow this order, keeping only the sections the source has:

1. **Dateline lead paragraph**, plain text (not bold):
   `NEW YORK, NY, UNITED STATES, October 22, 2026 -- FinTech Studios, ...`
   Use the city and date the release itself gives, and `--` after the date.
2. Remaining lead paragraphs, verbatim.
3. Short feature/control lists as bold-label bullets with blank lines between:
   `- **Title Case Label**: Sentence from the release.`
   A two- or three-column "strip" in an email becomes such a list under the
   paragraph that introduces it.
4. **Executive quotes as blockquotes**, one per person:
   `> "Full quote..." — Jim Tousignant, Founder and CEO of FinTech Studios`
   When the release splits a quote with `said X`, rejoin the halves into one
   quote and move the attribution to the end. Keep the quote's words verbatim.
5. `## <Section heading>` for each section, verbatim heading text.
   Feature lists inside use the bold-label bullet form; turn a bolded lead-in
   sentence ("**Create a collection.** Set up...") into
   `- **Create a Collection**: Set up...`.
6. Use cases or customer examples: `### <Use case> for <Audience>` subsections;
   quoted user prompts in `*"..."*`.
7. Setup steps (if any): `## Connect in Under a Minute` (or the release's
   heading) as bold-label bullets, not a numbered list. Avoid repeating the
   label as the first word of the sentence ("**Sign In**: Use your account").
8. `## Availability` (channels as bold-label bullets, then pricing/credits).
9. `## About FinTech Studios`, verbatim from the release (it varies by release;
   don't swap in the boilerplate from an older one). Add ™/® marks the way the
   existing entries do: FTS Studio™, PowerIntell.AI™, Apollo Pro®, RegLens Pro®.
10. `## Media Contact` if the release has one: name and title as one paragraph,
    then `[email](mailto:...) | phone | [www.fintechstudios.com/contact](/contact)`
    as the next.
11. Trademark footnote in italics when third-party products are named:
    `*Claude is a trademark of Anthropic, PBC. ChatGPT is a trademark of OpenAI. Perplexity is a trademark of Perplexity AI, Inc. All other trademarks are the property of their respective owners.*`

## Checklist before committing

- [ ] New object is first in the array; slug unique
- [ ] Headline, deck, quotes and About verbatim
- [ ] No bare URLs, no ordered lists, no tables
- [ ] Blank line between all blocks
- [ ] Backticks escaped inside the template literal
- [ ] Build output lists `/press/<slug>`; page checked at phone width
