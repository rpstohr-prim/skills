# Drizzle (`shared/schema.ts`) → PostgreSQL

Translate the diff by hand. Column names are the string passed to the builder
(`varchar("user_id")` → `user_id`), not the TypeScript property.

| Drizzle | SQL |
|---|---|
| `varchar("id").primaryKey().default(sql\`gen_random_uuid()\`)` | `id varchar PRIMARY KEY DEFAULT gen_random_uuid()` |
| `varchar("x")` / `varchar("x", { length: 50 })` | `x varchar` / `x varchar(50)` |
| `text("x")` | `x text` |
| `integer("x")` / `bigint("x", { mode: "number" })` | `x integer` / `x bigint` |
| `serial("x")` | `x serial` |
| `real("x")` / `doublePrecision("x")` / `numeric("x", { precision: 12, scale: 4 })` | `real` / `double precision` / `numeric(12,4)` |
| `boolean("x").notNull().default(false)` | `x boolean NOT NULL DEFAULT false` |
| `timestamp("x").defaultNow()` | `x timestamp DEFAULT now()` |
| `timestamp("x", { withTimezone: true })` | `x timestamptz` |
| `jsonb("x").$type<…>()` | `x jsonb` |
| `jsonb("x").default([])` / `.default({})` | `x jsonb DEFAULT '[]'::jsonb` / `'{}'::jsonb` |
| `text("x").array()` | `x text[]` |
| `.notNull()` | `NOT NULL` — on an existing table only together with a `DEFAULT`, or after a backfill |
| `.unique()` | `ADD CONSTRAINT <table>_<col>_unique UNIQUE (<col>)` (Drizzle's naming) |
| `.references(() => users.id, { onDelete: "cascade" })` | `REFERENCES users(id) ON DELETE CASCADE` |
| `index("name").on(t.col)` | `CREATE INDEX IF NOT EXISTS name ON table (col)` |
| `uniqueIndex("name").on(t.a, t.b)` | `CREATE UNIQUE INDEX IF NOT EXISTS name ON table (a, b)` |
| `pgEnum("status", ["a","b"])` | `DO $$ BEGIN CREATE TYPE status AS ENUM ('a','b'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;` |
| new enum value | `ALTER TYPE status ADD VALUE IF NOT EXISTS 'c';` (cannot run inside a transaction block on PG < 12; fine on 16, but the new value can't be used in the same transaction) |

## Idempotent forms

```sql
ALTER TABLE t ADD COLUMN IF NOT EXISTS c text;
ALTER TABLE t DROP COLUMN IF EXISTS c;                    -- contract step only
CREATE TABLE IF NOT EXISTS t (...);
CREATE INDEX IF NOT EXISTS i ON t (c);
CREATE INDEX CONCURRENTLY IF NOT EXISTS i ON big_table (c); -- not inside BEGIN/COMMIT
ALTER TABLE t ALTER COLUMN c SET DEFAULT 'x';
-- constraints have no IF NOT EXISTS:
DO $$ BEGIN
  ALTER TABLE t ADD CONSTRAINT t_c_unique UNIQUE (c);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL; END $$;
```

## Checking the live schema matches the code

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = '<table>'
ORDER BY ordinal_position;

SELECT indexname, indexdef FROM pg_indexes WHERE tablename = '<table>';
```

Dev and prod can drift (dev had extra tables from unmerged branches). Before
writing SQL for prod, check the column isn't already there — or that dev isn't the
only place it exists.
