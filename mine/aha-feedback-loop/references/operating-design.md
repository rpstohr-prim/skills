# Operating design

Agree this with the owner after discovery, and record it as the design the agent follows. The
status names are examples from a typical Aha! idea workflow; replace them with the workspace's.

## States (tracked in the agent's state file)

| State | Meaning | Moves it on |
|---|---|---|
| new | idea seen, not yet triaged | agent |
| needs-info | question to the client posted (approved); waiting | client reply → agent |
| proposed | in the owner's digest | owner |
| approved | owner said yes; promoted / waiting for the lead to dispatch | lead |
| in-progress | a dev thread is working it; PRs say "Refs #n" | lead / team |
| merged | on main, not yet deployed | release pipeline |
| live | deployed; behaviour not yet checked | agent |
| verified | behaviour confirmed on the live site | agent (or owner, if sign-in is needed) |
| in-review | idea set to Ready for Client Review with the approved note; timer running | client / timer |
| closed | issue closed, idea Complete, resolution posted | agent |
| answered / declined / duplicate | no code change; approved reply posted | agent, with owner OK |

## Intake

- Poll several times per business day (e.g. every 2 h during the owner's working hours, plus a
  morning digest). Read ideas, features, and **all three comment lists** (idea portal, idea
  workspace, feature).
- The first run records a silent baseline. After that, report new ideas, idea status changes,
  idea → feature → issue links, new comments (client vs internal, by a list of internal Aha! user
  ids), and features with no idea (leaked internal issues).

## Triage (per idea, read-only)

Use the code, the docs/guides, the live product and read-only data. Never write.

1. **Type**: defect · content · question · enhancement (held if the project is in defect-only mode,
   unless the owner approves) · duplicate · needs-info.
2. **Priority**, by rubric:
   - **P0**: blocks the client or exposes data. Drop everything; push-notify the owner.
   - **P1**: wrong or misleading for every user, or visible in every session.
   - **P2**: clearly wrong but contained (one screen, one item, has a workaround).
   - **P3**: polish, wording preference, rare edge.
3. **Area and owning team/thread**, from a component → owner table for the project.
4. **Evidence**: where it happens; whether you reproduced it and how; the root cause if found
   read-only.
5. **Group by fix, not by ticket.** One root cause = one fix; list every idea it resolves.
6. **Duplicates**: search open and recently closed issues and the state file first.
7. **Systemic check (the most valuable step).** When feedback is about one instance, ask whether a
   rule, template or pipeline caused it and will repeat it. Propose fixing the source as well as
   the instance, and size both.
8. **Proposed disposition** in one paragraph: what changes, who, size (S/M/L), owner actions, and how
   it will be verified live.

## The five recommendation types (plus the fix-flow ones)

| Recommendation | On the owner's yes, the agent… | Idea status |
|---|---|---|
| Fix | promotes the idea to a feature (API, into the agreed release); the integration opens the issue | Planned (automatic) |
| Question | posts the approved answer | Explanation Given |
| Alternative | posts the approved reply | Will not implement (or Future consideration) |
| Unclear | posts the approved question; a client reply re-enters triage | Feedback Requested |
| Duplicate | posts a pointer to the original | Duplicate Idea |
| Review (fix verified live) | posts the approved "what changed, how to see it" note | Ready for Client Review |
| Close (client confirmed) | closes the issue with the approved client-tone summary | Shipped → Complete (native) |

Never invent product behaviour in an answer. If the honest answer is "the docs are unclear here",
say so in the digest and log it as a docs gap.

## Approval-gated writes

- Each write is one **approval record**: the exact action (incl. text and target), its SHA-256, when
  and where the owner said yes ("owner in chat", "digest <date> item 3, relayed by lead").
- The executor refuses an action whose hash changed, is a **dry run unless told to post**, keeps a
  **ledger** so nothing runs twice, also checks whether the comment/status is already on the record
  (survives a lost ledger), and **reads the result back**.
- Endpoints are an **allow-list**: promote, portal comment, workspace comment, idea status, release
  lookup; GitHub comment and close via the existing `gh` login. The agent never sets Complete
  directly. Only the native sync does, on close.

## Fix flow

1. Promotion opens the issue. The lead dispatches. Every PR says **"Refs #n"**, never Closes/Fixes:
   closing syncs to the client. Put this rule in the repo's agent guide and PR template.
2. **Live** = a successful deploy on main whose commit contains the PR's merge commit and that
   released to the environment the client uses. Record the run id.
3. **Verified** = the behaviour shows on the live site (served bundle, read-only data check, or the
   owner's signed-in check).
4. **Review**: set the idea to Ready for Client Review and post the approved note. The timer starts
   at the status time Aha! records (`workflow_status_times`).
5. **Close**: the client confirms → post the approved summary on the issue and close it. The client
   says it isn't right → reopen and re-triage. (Check on the first case whether reopening moves the
   feature back from Shipped; a manual status change is client-visible and needs the owner's yes.)
   Act only on an **unmistakable** confirmation; anything ambiguous goes to the digest.

## Timeout auto-close (the one standing approval)

- No client reply (portal, idea or feature comment from a non-internal user) within **N US business
  days** after the review started → post the **fixed note** on the idea (agreed target), then close
  the issue with the same text.
- Business days: weekdays that aren't US federal holidays, with Saturday holidays observed on the
  Friday and Sunday holidays on the Monday. Count in the owner's home time zone, even when they
  travel.
- The fixed text is approved verbatim once and never reworded per item. Item-specific wording needs a
  normal approval. Ask the owner whether they want a heads-up line in the digest the business day
  before each auto-close.
- Example fixed text: "Closed after 10 business days without further feedback. Reply on this idea if
  anything still isn't right and we'll reopen it."
- Off by default; turned on in config only after the owner confirms the standing authority directly.

## Field ownership (template)

| Record · field | Single writer | How | Client sees? |
|---|---|---|---|
| Idea creation | Client (portal) | — | yes |
| Promote idea → feature (opens GH issue) | Agent on the owner's yes (or the internal promoter) | API / UI | idea → Planned (may email) |
| Feature ↔ issue link, title, description | Native integration | automatic | if seats |
| Release ↔ milestone | Owner / promoter | native | if seats |
| Feature comments | Lead via GitHub comments (native sync) | `gh` | if seats: client tone only |
| Feature → Shipped | GitHub close (native) | `gh issue close` after verify + approval | yes, via idea → Complete |
| Intermediate feature statuses | nobody (default) | — | — |
| Idea comments (answers, questions, review notes, resolutions) | Agent via API, owner-approved, as the key's user | API | yes |
| Idea statuses (no-fix, needs-info, review) | Agent via API, owner-approved | API | yes (may email) |
| GitHub labels for triage (`type:*`, `P0–P3`, `area:*`, state) | Agent | `gh` | no (not synced) |
| Internal notes | nowhere in Aha!: agent log / internal issue (once import is approve-first) | — | no |

## Status mapping (template)

| Agent state | Feature (internal) | Idea (client) | Writer | Email risk |
|---|---|---|---|---|
| new (unpromoted) | — | New | — | — |
| proposed → promoted | New (created) | Planned (auto) | agent / promoter | likely |
| needs-info | — | Feedback Requested + question | agent | likely |
| approved / in-progress / merged / live | unchanged | unchanged | — | none |
| verified → in-review | unchanged | Ready for Client Review + note | agent | likely |
| closed (fix) | Shipped (GH close) | Complete (auto) + resolution | agent / lead | likely |
| answered | — | Explanation Given + answer | agent | likely |
| declined | Will not implement (if promoted) | Will not implement + reason | agent | likely |
| duplicate | — | Duplicate Idea + pointer | agent | likely |

## Measures (put them in each digest)

Time to triage · time from approval to live · open items by priority · items waiting on the owner ·
reopen rate.
