# The tool: reference implementation

The reference implementation is the `feedback-loop` package (TypeScript, Node 22, Zod) in the owner's
`Fintech-Studios-Apps/Waypoint` repository, at `packages/feedback-loop`. It's a private workspace
package with a CLI that runs on the owner's machine and is never deployed. Copy it into another
repo, or build the equivalent, in this order, one small PR each:

1. **Read-only intake and digest**: Aha! GET client, Keychain token, poller, state, business-day
   calendar, review timers, GitHub context, digest renderer.
2. **Approval-gated writes**: approval records, executor, ledger, allow-listed Aha! writer, `gh`
   writer.
3. **Fix flow**: deploy evidence for merged PRs, review-timer hooks, timeout auto-close.
4. **Scheduling**: a scheduled task (e.g. every 2 h on weekdays in the owner's working hours, plus a
   morning digest) that runs poll → digest and the timeout close, with a push notification only for
   P0. Use a local scheduler first; a hosted webhook service needs a public endpoint, secret storage
   and a security review, so only with the owner's approval.

## Configuration (`<state dir>/config.json`, outside the repo, 0600)

```json
{
  "baseUrl": "https://<subdomain>.aha.io",
  "product": "<PRODUCT PREFIX>",
  "githubRepo": "<owner>/<repo>",
  "timeZone": "America/Denver",
  "reviewBusinessDays": 10,
  "internalUserIds": ["<Aha! user ids whose comments are internal: the owner, the integration's user>"],
  "replyTargets": ["portal"],
  "autoClose": false
}
```

The state directory defaults to `~/Documents/Projects/<project>/feedback/`, or is set with
`--dir` or `$FEEDBACK_DIR`. Files: `state.json` (ids, titles, agent states, review start times, seen
comment ids), `last-events.json`, `recommendations.json` (the agent's digest items),
`approvals.json`, `writes.json` (the ledger).

## CLI

```bash
pnpm --filter @<scope>/feedback-loop build
FL="node packages/feedback-loop/dist/cli.js"

$FL poll [--dry-run]           # read Aha!, record changes, print events (first run = silent baseline)
$FL context <IDEA-REF>         # the idea, its comments (portal + workspace + feature), GitHub issue and PRs
$FL digest [--recs file]       # the owner's digest from the last poll + recommendations.json + timers
$FL timers                     # ideas in client review and their auto-close dates
$FL mark <IDEA-REF> <state> [--group g] [--review-started iso] [--exclude]   # local state only
$FL approve --id <id> --source "<where the owner said yes>" --action action.json
$FL apply <id> [--post]        # dry run unless --post; never repeats; reads back
$FL approvals                  # each approval and whether it ran
$FL fixes                      # per open issue: merged PRs and the deploy run that made each live
$FL autoclose [--post]         # timeout close, fixed text only, skips client replies; needs autoClose:true
```

Action files:

```json
{ "kind": "promote", "ideaRef": "ABC-I-7", "releaseRef": "ABC-R-2" }
{ "kind": "idea-comment", "ideaRef": "ABC-I-8", "target": "portal", "text": "…exact approved text…" }
{ "kind": "idea-status", "ideaRef": "ABC-I-8", "status": "Explanation Given" }
{ "kind": "issue-comment", "issue": 123, "text": "…client-tone…" }
{ "kind": "issue-close", "issue": 123, "text": "…approved closing summary…" }
```

`recommendations.json` items: `{ refs[], kind (fix|question|alternative|unclear|duplicate|review|close|plan), priority?, title, type?, thread?, size?, ownerAction?, proposal, draftReply? }`.

## Aha! endpoints used

| Purpose | Method and path | Body |
|---|---|---|
| list ideas / features | `GET /api/v1/products/:prefix/ideas` · `/features` (paged, `per_page=100&page=n`) | — |
| one idea / feature | `GET /api/v1/ideas/:ref` · `/features/:ref` | — |
| workspace comments | `GET /api/v1/ideas/:ref/comments` · `/features/:ref/comments` | — |
| portal comments | `GET /api/v1/ideas/:ref/idea_comments` | — |
| release id | `GET /api/v1/releases/:ref` | — |
| promote | `PUT /api/v1/ideas/:ref/promote` | `{"promotable_type":"feature","release_id":"<id>"}` |
| portal comment | `POST /api/v1/ideas/:ref/idea_comments` | `{"idea_comment":{"body":"<p>…</p>","visibility":"public"}}` |
| workspace comment | `POST /api/v1/ideas/:ref/comments` | `{"comment":{"body":"<p>…</p>"}}` |
| idea status | `PUT /api/v1/ideas/:ref` | `{"idea":{"workflow_status":"<status name>"}}`: confirm on first use by reading back |

HTML-escape comment text and wrap paragraphs in `<p>`.

## Deploy evidence ("live")

For each merged PR whose body says `Refs #n`, take its merge commit and find the newest successful
deploy run on main whose head contains it (`gh api repos/:repo/compare/<merge>...<head>` → `ahead` or
`identical`) and whose release job succeeded (`gh run view <id> --json jobs`). Record the run id and
time. Adjust the workflow and job names to the project.
