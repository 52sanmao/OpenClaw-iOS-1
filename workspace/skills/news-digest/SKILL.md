---
name: news-digest
description: >-
  Generates temporal digest narratives (day/week/month/quarter) from enriched
  news items in the mcpapp-store.com database. Creates new digests or updates
  existing ones. Script fetches items; agent writes the narrative. Run on a
  schedule or manually for a specific date.
---

# News Digest — Generation

Reads enriched news items from the DB and writes curated digest narratives for a given period.

---

## Your workflow (3 steps)

### 1. Fetch items for the period

```bash
# Daily digest for today
bash /home/openclaw/news_digest_fetch.sh --mode day

# Daily digest for a specific date
bash /home/openclaw/news_digest_fetch.sh --mode day --date 2026-04-02

# Weekly digest (week containing the given date)
bash /home/openclaw/news_digest_fetch.sh --mode week --date 2026-04-02

# Monthly
bash /home/openclaw/news_digest_fetch.sh --mode month --date 2026-04-02

# Quarterly
bash /home/openclaw/news_digest_fetch.sh --mode quarter --date 2026-04-02
```

Output JSON fields:
- `mode` — day / week / month / quarter
- `period_key` — e.g. `2026-04-02`, `2026-W14`, `2026-04`, `2026-Q2`
- `period_label` — human readable, e.g. `April 2, 2026`
- `date_from`, `date_to` — ISO dates bounding the period
- `existing_digest` — null if doesn't exist yet, or `{ id, title, summary_md, item_count }` if it does
- `item_count` — number of enriched items in this period
- `items` — array of enriched news items (title, url, summary, image_url, tags, source_name)
- `sub_digests` — for week/month/quarter: child digest summaries to build the narrative from

**If `item_count` is 0 — stop. Nothing to write. Exit cleanly.**

**If `existing_digest` is not null — you are updating an existing digest, not creating a new one.**

---

### 2. Write the digest

Write these fields:

**`title`** — clear, specific title for the period.
- Day: `"AI News — April 2, 2026"`
- Week: `"AI News — Week of March 30, 2026"`
- Month: `"AI in March 2026: Monthly Roundup"`
- Quarter: `"AI in Q2 2026: Quarterly Review"`

**`summary_md`** — the narrative. Markdown. Tone: analytical, developer-focused, no fluff.

**Per mode, write at a different abstraction level:**

**Day (150–250 words):**
- What happened today? Lead with the biggest story.
- Cover each item in 1-2 sentences. Group thematically if natural.
- End with a one-liner on the day's overall theme if there is one.
- Format: prose paragraphs + item list with links.

```markdown
[narrative intro paragraph]

**Today's stories:**
- **[Title](url)** (Source) — one sentence on why it matters.
- ...
```

**Week (250–400 words):**
- What were the 2-3 big themes this week?
- Which stories mattered most and why?
- Build from `sub_digests` if they exist, otherwise from raw items.
- Format: themed sections + item links.

**Month (400–600 words):**
- What were the major developments this month?
- What trends emerged? What shifted?
- Build from weekly `sub_digests`. Reference them explicitly.
- Format: narrative sections by theme.

**Quarter (600–800 words):**
- The narrative arc. What changed in the space this quarter?
- Milestone moments, trend lines, what it means going forward.
- Build from monthly `sub_digests`.
- Format: long-form narrative, 3-4 sections with headings.

**`item_ids`** — list of UUIDs from `items[].id`. **Must be populated before saving** — populate this from the fetch output `items[].id` array. Include all items for day/week. For month/quarter, include the most significant ones (up to 20).

**`item_count`** — integer, number of items covered.

**`mode`** — passthrough from fetch output.

**`period_key`** — passthrough from fetch output.

---

### 3. Save

⚠️ **The save script reads from `/tmp/digest_enriched.json` — that exact filename. Do not use any other filename.**

Write to `/tmp/digest_enriched.json`:

```json
{
  "mode": "day",
  "period_key": "2026-04-02",
  "title": "AI News — April 2, 2026",
  "summary_md": "...",
  "item_ids": ["uuid1", "uuid2", ...],
  "item_count": 7
}
```

Then run:

```bash
bash /home/openclaw/news_digest_save.sh
```

This upserts to the `digests` table — creates if new, updates if exists.

⚠️ **Common mistake:** writing to `/tmp/digest_result.json` or any other filename will silently do nothing — the save script only reads `/tmp/digest_enriched.json`.

---

## Implementation note (for agents)

When generating multiple digests in a loop, **use Python** to build and write the JSON — shell heredocs with embedded quotes/f-strings cause quoting errors. Recommended pattern:

```python
import json, subprocess
obj = {
    "mode": data["mode"],
    "period_key": data["period_key"],
    "title": title,
    "summary_md": summary_md,
    "item_ids": [it["id"] for it in data["items"]],
    "item_count": data["item_count"],
}
with open("/tmp/digest_enriched.json", "w") as f:
    json.dump(obj, f, ensure_ascii=False, indent=2)
subprocess.run(["bash", "/home/openclaw/news_digest_save.sh"], check=True)
```

---

## Quality bar

A good digest:
- Has a real narrative, not just a list of links
- Leads with the most significant story for the period
- Groups related items thematically where natural
- Weekly/monthly/quarterly adds genuine synthesis — not just a summary of summaries
- Is written for an AI developer audience (MCP, agents, models, tooling)

A bad digest:
- Just repeats item summaries bullet-by-bullet
- Has no editorial voice or judgment about what mattered most
- Uses filler phrases ("In the rapidly evolving world of AI...")

---

## Cron usage

Run daily at 06:00 UTC (generates yesterday's digest):
```bash
bash /home/openclaw/news_digest_fetch.sh --mode day
```

Run weekly on Monday at 07:00 UTC (generates last week's digest):
```bash
bash /home/openclaw/news_digest_fetch.sh --mode week --date $(date -d 'last monday' +%Y-%m-%d)
```

Run monthly on 1st at 08:00 UTC:
```bash
bash /home/openclaw/news_digest_fetch.sh --mode month --date $(date -d 'last month' +%Y-%m-%d)
```

---

## Reference

See `references/db-schema.md` for digests table definition.
