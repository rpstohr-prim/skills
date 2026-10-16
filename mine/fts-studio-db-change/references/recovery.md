# Recovery — when a database change went wrong

All SQL here is run by the user in Cloud SQL Studio as `postgres`. Use the right
role for the instance: prod `studio-app-db@elasticsearch-496414.iam`, dev
`studio-dev-db@elasticsearch-496414.iam`.

## "permission denied for table …" after a migration

Objects were created without `SET ROLE`, so `postgres` owns them. Hand them to the
app:

```sql
-- what is wrong
SELECT tablename, tableowner FROM pg_tables
WHERE schemaname = 'public' AND tableowner NOT LIKE 'studio-%db@%';

-- fix one table (repeat per table; sequences behind serial columns follow the table)
ALTER TABLE <table> OWNER TO "studio-app-db@elasticsearch-496414.iam";

-- stray sequences or types
SELECT c.relname, pg_get_userbyid(c.relowner) FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'S' AND pg_get_userbyid(c.relowner) NOT LIKE 'studio-%db@%';
ALTER SEQUENCE <seq> OWNER TO "studio-app-db@elasticsearch-496414.iam";
ALTER TYPE <enum> OWNER TO "studio-app-db@elasticsearch-496414.iam";
```

No app restart is needed.

## "must be owner of table" when running SQL

You're `postgres` without the role. Add `SET ROLE "<app role>";` at the top. If it
says `permission denied to set role`, `postgres` lost membership:

```sql
GRANT "studio-app-db@elasticsearch-496414.iam" TO postgres;
```

## "column … does not exist" right after a deploy

Code merged before the SQL ran on prod. Fastest fix: run the migration SQL on
prod now (it's idempotent) — the running pod picks it up immediately. If the SQL
isn't ready, roll the image back
(`kubectl --context gke_elasticsearch-496414_us-central1-b_fts-prod-gcp -n studio-prod rollout undo deployment/studio`)
and confirm with the user first.

## A migration half-applied

Every statement is idempotent, so fix the failing statement and run the whole
script again. For multi-statement data fixes, use `BEGIN; … COMMIT;` so a failure
rolls back cleanly (but `CREATE INDEX CONCURRENTLY` and some `ALTER TYPE … ADD
VALUE` uses can't be in a transaction — run those on their own).

## Need the data back

`studio-prod-db` has daily backups and 7 days of point-in-time recovery
(Console → SQL → studio-prod-db → Backups). A restore overwrites the instance or
creates a new one — always the user's decision, never automatic. For one table,
the safer path is restoring to a **new** instance and copying the rows back.

## `postgres` password

Only Cloud SQL Studio and the data-copy script use it; the app logs in with IAM
and is unaffected by a reset. Reset: Console → SQL → instance → Users → `postgres`
→ Change password. Prod and dev have different passwords — easy to reset the
wrong one, so check the instance name in the header first.
