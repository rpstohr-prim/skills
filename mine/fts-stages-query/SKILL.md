---
name: fts-stages-query
description: >-
  Build a correct FinTech Studios News API query — the POST /news/user/{userId}/query
  "stages" payload. Use whenever code searches FTS news by entity, topic, doctype,
  keyword or free text: collection/channel adapters, Discover search, saved searches,
  pipeline source nodes, agent tools, or any script hitting the FTS news endpoint.
  Also use when an FTS search returns zero articles for no obvious reason, when a
  filter appears to do nothing, or when deciding whether a term should be an entity
  id or a text string.
metadata:
  version: 1.0.0
---

# FTS stages query

The FTS news endpoint fails **silently**. A malformed request returns `200` with an
empty `articles` array, and an ignored field returns the *unfiltered* set. Neither
shows up as an error, so a wrong payload looks like "no news" or "the filter didn't
match" rather than a bug. Every rule below was verified against the live API
(Sep 2026) by paired requests where one thing varied — not inferred from our code,
which had three of them wrong.

## The request

```
POST {FTS_API_BASE}/news/user/{userId}/query
headers: x-api-key, Authorization: Bearer <jwt>, Content-Type: application/json
```

```json
{
  "stages": [ { "not": false, "entities": [ { "type": "entity", "value": 7628280, "options": {} } ] } ],
  "start_time": 1787158355647,
  "end_time":   1789750355647,
  "count": 100,
  "offset": 0
}
```

That is the whole contract. Anything else is either ignored or actively harmful.

## The five rules that matter

**1. `userId` is the login-response `userId`, not the JWT `sub`.**
For the shared system account these differ — `sub` is an `auth0|…` id and `userId`
is a UUID. Using `sub` gives `403 Cannot access news for user …`. Use
`getFtsUserId()`, never `extractFtsUserId(await getFtsToken())`.

**2. Dates are `start_time`/`end_time`. Never send `start`.**
`start` is not a date field — FTS reads it as a record offset. A millisecond
timestamp there asks for results past the end of the set and you get `200` with
zero articles. Measured: a working request returns 50 articles; add `start` and it
returns 0. `end` alone is harmless, and an unknown key like `junkKey` changes
nothing — so this is `start` being *interpreted*, not schema validation.

**3. Paging is `count` + `offset`. `size`/`from` are ignored.**
Asking `size: 3` returns the default 25. Omitting `count` also gives 25. `count`
maxes at 1000; above that you get an empty array with a 200. `offset` reaches 5000.

**4. The top-level `query` field is ignored.**
A nonsense term in `query` still returns the full result set. Free text only
filters as a `keyword` entity inside a stage. Any code joining terms into `query`
is a no-op filter.

**5. Multi-word terms must be quoted to match as a phrase.**
Measured by `hits.count`: `unexplained wealth order` bare matches 135, and so does
the same three words reversed — bare is word-order independent. Quoted, the real
phrase drops to 17 and the reversed one to 0. Single words gain nothing from
quotes.

## Stage algebra

- **Entities within a stage OR.** `[entity A, keyword B]` in one stage matches
  either. Proven: adding a nonsense keyword to an entity's stage leaves the count
  unchanged (95 → 95), because a union with nothing is itself.
- **Stages AND.** Entity stage + keyword stage narrowed 95 → 93.
- **`not: true` makes a stage exclude.**

So group terms the user means as "any of these" into one stage, and separate
independent filters into their own stages.

## Entity first, text as the fallback

FTS resolves a word or phrase to a taxonomy entity when it can, and an entity match
is always better — it is curated, not string matching. The taxonomy is not
exhaustive, which is why stages also carry text. So:

1. Try to resolve the term (`/entity/search/{q}?include=…`).
2. Resolved → `{ "type": "entity", "value": <ftsId> }`.
3. Unresolved → `{ "type": "keyword", "value": "\"the phrase\"" }` in the same
   stage.

Never drop an unmatched concept, and never demote it to a filter the request does
not carry. For an FTS-only surface, a term that is not in the payload filters
nothing at all.

## Document types are not a stage

Doc types live in article metadata (`metadata.docTypes`), so filter them
**post-fetch** as an include list. A doctype stage zeroes the result set.

## Relevance

`options: { relevance: "high" | "medium" | "low" }` narrows to how central the
entity is to the article. `options: {}` applies no threshold — every document for
that entity. Omitting relevance is what you want for "everything from this agency".

## Before you ship a change

Assume nothing about this API from reading our own code — four call sites in
FTS-Web built this payload four different ways and three were wrong. Probe it:
send the same query twice with one field changed and compare **`hits.count`**, the
uncapped total. Comparing `articles.length` measures your own page size instead of
the filter. Use a nonsense term as your negative control: a filter that works
returns 0 for it, one that is ignored returns the full set.

See `references/api-reference.md` for the full field list, response shape, and the
measurements behind each rule.
