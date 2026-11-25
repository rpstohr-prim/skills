# Discovery (phase 0, read-only)

Goal: know exactly what already moves between Aha! and GitHub, and what the client sees, before
designing or writing anything. About half a day. Write nothing to Aha!, GitHub issues or labels,
or any database.

Parameters used below: `$AHA` = `https://<subdomain>.aha.io`, `$PRODUCT` = the workspace's
reference prefix (e.g. `ABC`), `$REPO` = `owner/name`.

## 1. GitHub side (no Aha! access needed)

```bash
# Issues the Aha! GitHub App opened (their body ends with "Aha! Link: …/features/<REF>")
gh issue list --repo $REPO --state all --search "author:app/integrate-with-aha" --limit 100 \
  --json number,title,state,createdAt,closedAt,milestone

# What the integration does to an issue over time (milestone = Aha! release, issue type, …)
gh api repos/$REPO/issues/<n>/timeline --jq '.[] | "\(.event) \(.actor.login // "") \(.created_at // "") \(.milestone.title // "")"'

# Milestones the integration created (one per Aha! release)
gh api "repos/$REPO/milestones?state=all" --jq '.[] | "\(.title) by \(.creator.login)"'
```

Record: which records became issues, whether a release change moved the milestone, whether it sets
an issue type, and whether **issues created in GitHub show up in Aha!** (create nothing to test this
yet; look for features without an idea in step 2).

## 2. Aha! side (needs the key, see setup-and-security.md)

Use GET only, under 7 requests a second, with a generic User-Agent (no personal contact details).
Save raw output outside the repo with `chmod 600`.

| Question | Call |
|---|---|
| Whose key, what role in this workspace | `GET /api/v1/me` → `product_roles` |
| Workflows (feature, idea, release) | `GET /api/v1/products/$PRODUCT` → `feature_workflow.id`, `idea_workflow.id`; then `GET /api/v1/workflows/<id>` |
| Releases | `GET /api/v1/products/$PRODUCT/releases` |
| Features and their GitHub link | `GET /api/v1/products/$PRODUCT/features`; per feature `GET /api/v1/features/<REF>` → `integration_fields` (`number`, `url`), `release`, `created_by_user` |
| Ideas and their feature | `GET /api/v1/products/$PRODUCT/ideas`; per idea `GET /api/v1/ideas/<REF>` → `feature`, `workflow_status`, `workflow_status_times`, `visibility` |
| Workspace comments | `GET /api/v1/features/<REF>/comments`, `GET /api/v1/ideas/<REF>/comments` |
| **Portal comments** (what the submitter sees) | `GET /api/v1/ideas/<REF>/idea_comments` |
| Integration settings | `GET /api/v1/products/$PRODUCT/integrations`: needs an owner/admin role (403 for contributors), so ask for a screenshot instead |
| Portal email settings | Not readable with a contributor key; ask the owner to check the portal's email settings |

## 3. Establish these facts and write them down

1. **The chain.** Typically: the client submits an idea → an internal user **promotes** it to a
   feature (the idea moves to e.g. Planned) → the integration opens a GitHub issue within seconds →
   closing the issue sets the feature to Shipped → Aha!'s automation sets the idea to Complete. Time
   each step from `workflow_status_times` against the issue timeline.
2. **Where synced comments land.** GitHub comments sync to the **feature**, posted as the
   integration's Aha! user, **not** to the idea. Portal users never see them in the portal.
3. **Does the client have workspace seats?** Ask the owner. If yes, apply **rule zero**: everything
   in Aha!, including features and synced comments, is client-visible.
4. **Two comment lists on an idea.** `/comments` = workspace comments (inside Aha! only).
   `/idea_comments` = portal comments (shown on the idea's portal page; the submitter replies there;
   may email the submitter and voters). Decide with the owner which one client replies use.
5. **Which status changes email whom.** Portal default: an idea's subscribers (the submitter and
   voters) are emailed on status changes. Until the owner confirms the portal's email settings, treat
   **every idea status change as an email to the client**.
6. **Import of new GitHub issues.** If every new repo issue becomes an Aha! feature (look for features
   with no idea whose issue a person created), internal work leaks to the client. The fix is an admin
   setting: GitHub integration → import new records → **"Approve new records before importing"**.
   This is separate from status and comment sync, which keep working. Until it's changed: no new
   internal GitHub issues, and remove the leaked feature (unlink it from the issue first, then delete).
7. **Unpromoted ideas.** Ideas still in New have no GitHub issue. That's where triage fits best:
   before promotion.
8. **The key's role.** A contributor can read, comment, change idea status and promote, but can't
   read integration or portal settings. If the key is the owner's own, every API write appears under
   the owner's name.

## 4. Report to the lead / owner

- The current flow (the chain above, with timings).
- A field-ownership table and a status mapping (templates in operating-design.md).
- What the native integration already does that the agent must not duplicate.
- Owner decisions needed: reply target, whether to use a "Ready for Client Review" step, the review
  period, the fixed auto-close text, the import setting, and the seats answer.
- A calibration triage of existing records, in the state file only, nothing posted.
