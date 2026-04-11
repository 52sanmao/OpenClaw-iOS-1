# News Digest DB Schema

## digests table

```sql
CREATE TABLE digests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_type TEXT NOT NULL,    -- 'day' | 'week' | 'month' | 'quarter'
    period_key  TEXT NOT NULL,    -- '2026-04-02' | '2026-W14' | '2026-04' | '2026-Q2'
    title       TEXT NOT NULL,
    summary_md  TEXT NOT NULL,    -- agent-written markdown narrative
    item_ids    UUID[],           -- references to news_items
    source_ids  UUID[],           -- derived from item_ids (unique sources in this digest)
    item_count  INTEGER NOT NULL DEFAULT 0,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (period_type, period_key)
);
```

## Key queries

```sql
-- Get today's digest
SELECT * FROM digests WHERE period_type='day' AND period_key='2026-04-04';

-- Get this week's digest
SELECT * FROM digests WHERE period_type='week' AND period_key='2026-W14';

-- All daily digests for a month (for weekly digest generation)
SELECT * FROM digests WHERE period_type='day' AND period_key LIKE '2026-04-%' ORDER BY period_key;

-- Get digest + its items
SELECT d.*, array_agg(n.title) as item_titles
FROM digests d
JOIN news_items n ON n.id = ANY(d.item_ids)
WHERE d.period_type='day' AND d.period_key='2026-04-02'
GROUP BY d.id;
```

## Period key formats

| mode    | period_key format | example      |
|---------|-------------------|--------------|
| day     | YYYY-MM-DD        | 2026-04-02   |
| week    | YYYY-WNN          | 2026-W14     |
| month   | YYYY-MM           | 2026-04      |
| quarter | YYYY-QN           | 2026-Q2      |
