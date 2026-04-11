#!/usr/bin/env python3
"""
save.py — AI Models Pricing
Reads /tmp/pricing_raw.json, upserts pricing fields on existing ai_models rows,
and inserts new paid models that aren't in DB yet.
"""

import json
from datetime import datetime, timezone

INPUT_PATH = "/tmp/pricing_raw.json"


def load_env():
    env = {}
    with open("/home/openclaw/.openclaw/workspace/site/.env.local") as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, _, v = line.partition('=')
                env[k.strip()] = v.strip()
    return env


def main():
    import psycopg2

    with open(INPUT_PATH) as f:
        models = json.load(f)

    if not models:
        print("No pricing data to save.")
        return

    env = load_env()
    conn = psycopg2.connect(env['DATABASE_URL'])
    now = datetime.now(timezone.utc)

    updated = 0
    inserted = 0
    errors = []

    with conn.cursor() as cur:
        for m in models:
            api_id = m.get("api_model_id")
            provider_slug = m.get("provider_slug")

            # Check if model exists by api_model_id or by matching slug pattern
            cur.execute(
                "SELECT slug FROM ai_models WHERE hf_model_id = %s OR slug = %s",
                (api_id, api_id)
            )
            existing = cur.fetchone()

            try:
                if existing:
                    # Update pricing on existing record
                    cur.execute("""
                        UPDATE ai_models SET
                            pricing_input = %s,
                            pricing_output = %s,
                            pricing_cached = %s,
                            updated_at = %s
                        WHERE slug = %s
                    """, (
                        m.get("pricing_input"),
                        m.get("pricing_output"),
                        m.get("pricing_cached"),
                        now,
                        existing[0],
                    ))
                    print(f"  📝 updated: {existing[0]}")
                    updated += 1
                else:
                    # Insert new paid model
                    import re
                    slug = re.sub(r'[^a-z0-9]+', '-', api_id.lower()).strip('-')[:80]
                    cur.execute("""
                        INSERT INTO ai_models (
                            name, slug, provider, provider_slug,
                            short_description, is_open_source, license,
                            family_slug, variant, parameter_count,
                            modalities_input, modalities_output,
                            is_active, is_featured,
                            source_url, model_card_url,
                            context_window, pricing_input, pricing_output, pricing_cached,
                            created_at, updated_at
                        ) VALUES (
                            %s, %s, %s, %s,
                            %s, %s, %s,
                            %s, %s, %s,
                            %s, %s,
                            %s, %s,
                            %s, %s,
                            %s, %s, %s, %s,
                            %s, %s
                        )
                        ON CONFLICT (slug) DO UPDATE SET
                            pricing_input = EXCLUDED.pricing_input,
                            pricing_output = EXCLUDED.pricing_output,
                            pricing_cached = EXCLUDED.pricing_cached,
                            updated_at = EXCLUDED.updated_at
                    """, (
                        m.get("display_name", api_id),
                        slug,
                        _provider_display(provider_slug),
                        provider_slug,
                        "",  # short_description — agent fills later if needed
                        m.get("is_open_source", False),
                        "Proprietary",
                        provider_slug,  # family_slug
                        _detect_variant(api_id),
                        None,
                        ["text"],
                        ["text"],
                        True,
                        False,
                        m.get("source_url", ""),
                        m.get("source_url", ""),
                        m.get("context_window"),
                        m.get("pricing_input"),
                        m.get("pricing_output"),
                        m.get("pricing_cached"),
                        now, now,
                    ))
                    print(f"  ➕ inserted: {slug}")
                    inserted += 1

            except Exception as e:
                errors.append((api_id, str(e)))
                conn.rollback()
                print(f"  ❌ {api_id}: {e}")
                conn = psycopg2.connect(env['DATABASE_URL'])

    conn.commit()

    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM ai_models")
        total = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM ai_models WHERE pricing_input IS NOT NULL")
        with_pricing = cur.fetchone()[0]

    conn.close()

    print(f"\n📊 Updated {updated} | Inserted {inserted} | Total in DB: {total} | With pricing: {with_pricing}")
    if errors:
        print(f"❌ Errors ({len(errors)}):")
        for api_id, err in errors:
            print(f"   {api_id}: {err}")


def _provider_display(slug):
    return {
        "openai": "OpenAI", "anthropic": "Anthropic",
        "google": "Google", "xai": "xAI",
        "deepseek": "DeepSeek AI", "mistral": "Mistral AI",
    }.get(slug, slug.title())


def _detect_variant(api_id):
    api_id = api_id.lower()
    if any(x in api_id for x in ["reasoning", "think", "r1", "o1", "o3", "o4", "qwq"]):
        return "reasoning"
    if any(x in api_id for x in ["mini", "flash", "haiku", "nano", "lite", "small"]):
        return "instruct"
    return "instruct"


if __name__ == "__main__":
    main()
