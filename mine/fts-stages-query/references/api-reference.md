# FTS news query — field reference and measurements

Endpoint: `POST {FTS_API_BASE}/news/user/{userId}/query`
Base: `https://global-api.fintechstudios.com`

Auth: `x-api-key: <FTS_API_KEY>` and `Authorization: Bearer <jwt>`, where the JWT
comes from `POST /auth/login` with `{email, password}` and the same api key header.

## Request fields

| Field | Type | Honoured | Notes |
|---|---|---|---|
| `stages` | array | yes | The filter tree. See below. |
| `start_time` | epoch ms | **yes** | Window start. |
| `end_time` | epoch ms | **yes** | Window end. |
| `count` | number | **yes** | Page size. Max 1000; above that returns empty with a 200. Omitted → 25. |
| `offset` | number | yes | Page start. Reaches 5000 total. |
| `start` | — | **harmful** | NOT a date. Read as a record offset; a timestamp here returns zero articles. |
| `end` | — | ignored | Harmless but meaningless. |
| `size` / `from` | — | ignored | Returns the default 25 regardless. |
| `query` | — | **ignored** | Top-level full text does nothing. Use a keyword entity in a stage. |
| `language` | array | unverified | e.g. `["en"]`. Sent by some call sites; not measured. |
| `user` | string | unverified | Duplicates the path's userId in some call sites; not measured. |

## Stage shape

```json
{ "not": false, "entities": [ { "type": "...", "value": ..., "options": {} } ] }
```

Entity types seen in production: `entity`, `keyword`, `topic`, `industry`,
`region`, and the mapped names used by the filtered-search route (`company`,
`exec`, `corptopics`, `gics`, `country`, `usfedagency`).

`options.relevance` is `high` | `medium` | `low`. `{}` = no threshold.

## Response

```json
{ "articles": [...], "hits": { "count": 43, ... }, "hiddenClusterMap": {}, "articleWorkflowStates": [] }
```

**`hits.count` is the total corpus match for the query**, independent of `count`.
Use it for any measurement — `articles.length` is capped by your page size and
will mislead you. Note it does not always equal `articles.length` on an uncapped
page (clustering), so treat it as the match count, not a guaranteed fetch count.
Some call sites read `news` as a fallback key for `articles`.

## Measurements (Sep 2026, FinCEN entity 7628280 unless noted)

**Date keys**, 30-day window:

| Body | Articles |
|---|---|
| `start_time`/`end_time` | 10 (at count 10) |
| `start`/`end` (ms) | 0 |
| `start`/`end` (seconds) | 0 |
| both pairs together | 0 |
| no dates at all | 50 (at count 50) |

**Isolating `start`**, added to a working request that returned 50:

| Added | Articles |
|---|---|
| `junkKey: 123` | 50 |
| `end` only | 50 |
| `offset: 0` | 50 |
| `start` only | **0** |
| `start` + `end` | **0** |

An unknown key is ignored, so this is `start` being interpreted, not validation.

**Paging**, asking for 3:

| Body | Articles |
|---|---|
| `count: 3` | 3 |
| `size: 3, from: 0` | 25 |
| neither | 25 |

**Top-level `query`**, uncapped baseline of 95:

| Body | Articles |
|---|---|
| stages only | 95 |
| `query: "cryptocurrency"` | 95 |
| `query: "zzzznotaword"` | 95 |
| `query: "\"anti-money laundering\""` | 95 |

Ignored outright. The same nonsense term as a keyword stage returns 0.

**Phrase quoting**, keyword stage alone, 30-day window, measured by `hits.count`:

| Value | hits.count |
|---|---|
| `unexplained wealth order` (bare) | 135 |
| `order wealth unexplained` (bare, reversed) | 135 |
| `"unexplained wealth order"` (quoted) | **17** |
| `"order wealth unexplained"` (quoted, reversed) | **0** |

Bare is word-order independent and matches 135 either way — it is looking for the
words, not the phrase. Quoted drops to 17 for the real phrase and 0 for the
reversed one. That is the whole argument for quoting multi-word terms.

**Stage algebra**, entity baseline 95:

| Stages | Articles | Reading |
|---|---|---|
| entity alone | 95 | — |
| keyword `the` alone | 1000 (capped) | — |
| entity stage + keyword `the` stage | 93 | separate stages AND |
| one stage: entity + keyword `zzzznotaword` | 95 | same stage ORs (union with nothing) |
| one stage: entity + keyword `FinCEN` | 1000 | same stage ORs (union is larger) |

## Measuring safely

**Read `hits.count`, not `articles.length`.** The page size caps the array, so two
very different filters both look like "1000" if you measure the array — that trap
cost real time during this investigation. `hits.count` is uncapped and compares
cleanly.

Always include a nonsense-term control: a filter that works returns 0 for it, and
one that returns the full set is being ignored.
