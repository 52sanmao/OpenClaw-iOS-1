# News Aggregator DB Schema

## news_sources
Tracks each news source we pull from.

```sql
CREATE TABLE news_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    rss_url TEXT,                    -- NULL = use scraper
    scraper_key TEXT,                -- matches SCRAPERS dict in news_fetch.py
    category TEXT,                   -- 'research' | 'industry' | 'tools' | 'general'
    active BOOLEAN NOT NULL DEFAULT true,
    last_fetched_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## news_items
Individual articles. Deduplicated by URL.

```sql
CREATE TABLE news_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES news_sources(id),
    title TEXT NOT NULL,
    url TEXT NOT NULL UNIQUE,
    summary TEXT,                    -- agent-written clean 2-3 sentence summary
    image_url TEXT,                  -- from og:image
    video_url TEXT,                  -- YouTube embed if present
    published_at TIMESTAMPTZ,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tags TEXT[],                     -- e.g. ['mcp', 'claude', 'agents']
    status TEXT NOT NULL DEFAULT 'pending'  -- 'pending' | 'enriched' | 'skipped'
);

CREATE INDEX ON news_items (published_at DESC);
CREATE INDEX ON news_items (source_id, published_at DESC);
CREATE INDEX ON news_items (status);
```

## digests
One row per period. Agent writes these after enrichment.

```sql
CREATE TABLE digests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_type TEXT NOT NULL,       -- 'day' | 'week' | 'month' | 'quarter'
    period_key TEXT NOT NULL,        -- '2026-04-04' | '2026-W14' | '2026-04' | '2026-Q2'
    title TEXT NOT NULL,
    summary_md TEXT NOT NULL,        -- markdown narrative
    item_ids UUID[],                 -- references to news_items
    item_count INT NOT NULL DEFAULT 0,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (period_type, period_key)
);
```

## Key queries

```sql
-- Items from last 24h for daily digest
SELECT * FROM news_items
WHERE published_at > NOW() - INTERVAL '24 hours'
AND status = 'enriched'
ORDER BY published_at DESC;

-- Get today's digest
SELECT * FROM digests
WHERE period_type = 'day' AND period_key = '2026-04-04';

-- Sources due for refresh (oldest first)
SELECT * FROM news_sources
WHERE active = true
ORDER BY last_fetched_at ASC NULLS FIRST;
```
