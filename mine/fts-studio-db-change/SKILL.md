---
name: fts-studio-db-change
description: >-
  Make a database schema or data change for FinTech Studios Studio (FTS-Web) on
  Cloud SQL — dev (studio-dev-db) and production (studio-prod-db). Use whenever
  shared/schema.ts changes (new table, column, index, enum, default), when a
  feature branch needs a migration, when the user asks for "the migration SQL",
  wants to run SQL against Studio's dev or prod database, backfill or fix rows,
  check whether a column/table exists in prod, or hits "permission denied for
  table", "must be owner of table", or "column does not exist" after a deploy.
metadata:
  version: 1.0.0
---

# Studio database changes (Cloud SQL)

Studio has no migrations folder: the schema is `shared/schema.ts` and changes are
applied **by hand as SQL**, dev first, then prod. Two things make this different
from the Replit days:

1. **Merging to `main` deploys production within ~10 minutes.** The SQL must be
   on prod *before* the merge, or the new code hits "column does not exist".
2. **Tables belong to the app's IAM role, not `postgres`.** SQL run as `postgres`
   without `SET ROLE` creates objects the app can't read → "permission denied".

| | Dev | Production |
|---|---|---|
| Instance | `studio-dev-db` | `studio-prod-db` |
| Database | `studio` | `studio` |
| App role | `studio-dev-db@elasticsearch-496414.iam` | `studio-app-db@elasticsearch-496414.iam` |
| Where to run SQL | Console → SQL → instance → **Cloud SQL Studio**, user `postgres` | same |

## Workflow

1. **Write the SQL from the schema diff.** `git diff origin/main -- shared/schema.ts`,
   then translate by hand (`references/drizzle-to-sql.md`). Don't run
   `drizzle-kit push` against Cloud SQL — it applies every branch's drift at once.
2. **Make it safe to re-run and safe to deploy around:**
   - Start with `SET ROLE "<app role>";` (see the table).
   - `IF NOT EXISTS` / `IF EXISTS` everywhere.
   - **Expand, then contract.** Add nullable or defaulted columns and new tables
     first; drop/rename/tighten (`NOT NULL` on existing rows, type changes) only in
     a later change, after no deployed code uses the old shape. A rollback
     (`rollout undo`) brings back the previous image, which must still work.
   - Large tables (`broadcast_hits`, `hubspot_sync_log`, `insights`,
     `credit_ledger`, `usage_events`): `CREATE INDEX CONCURRENTLY` (outside a
     transaction), and avoid rewriting defaults on huge tables.
3. **Put the SQL in your reply** as one fenced `sql` block per environment — the
   user runs it themselves. Never run it yourself and never ask for the `postgres`
   password.
4. **Dev first.** User runs it on `studio-dev-db`; deploy the branch to dev
   (`gh workflow run deploy-gke-dev.yml --repo Fintech-Studios-Apps/FTS-Web --ref <branch>`)
   and test.
5. **Prod before merge.** Risky change? Suggest a backup first:
   `gcloud sql backups create --instance studio-prod-db --description "before <change>"`.
   User runs the same SQL (with the prod role) on `studio-prod-db`, runs the
   verify query below, **then** merges.
6. **Record it** in the PR description: the SQL and "applied to dev/prod on <date>".

## Template

```sql
SET ROLE "studio-app-db@elasticsearch-496414.iam";   -- prod; dev: studio-dev-db@…

ALTER TABLE users ADD COLUMN IF NOT EXISTS example_flag boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS example_items (
  id varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id varchar NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS example_items_user_id_idx ON example_items (user_id);

RESET ROLE;
```

## Verify

```sql
-- the change landed
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'example_flag';
-- every table is owned by the app role (empty result = good)
SELECT tablename, tableowner FROM pg_tables
WHERE schemaname = 'public' AND tableowner NOT LIKE 'studio-%db@%';
```

Fixes for wrong ownership, failed partial runs and data backfills:
`references/recovery.md`.

## Data, not schema

Backfills and one-off fixes follow the same path (dev → prod, user runs it,
`SET ROLE`, idempotent `WHERE` clauses). Wrap multi-statement fixes in
`BEGIN; … COMMIT;` and show a `SELECT count(*)` of affected rows first.
Production holds real customer data: read-only questions are fine, but don't
copy prod rows into dev or out of GCP without the user's explicit OK.
