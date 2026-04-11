#!/usr/bin/env python3
"""
save.py — AI Models Seed
Reads /tmp/ai_models_enriched.json, upserts to ai_models table.
"""

import json, sys
from datetime import datetime, timezone

OUTPUT_PATH = "/tmp/ai_models_enriched.json"


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
    from psycopg2.extras import Json

    with open(OUTPUT_PATH) as f:
        models = json.load(f)

    if not models:
        print("No models to save.")
        return

    env = load_env()
    conn = psycopg2.connect(env['DATABASE_URL'])
    now = datetime.now(timezone.utc)

    saved = 0
    errors = []

    with conn.cursor() as cur:
        for m in models:
            try:
                cur.execute("""
                    INSERT INTO ai_models (
                        name, slug, provider, provider_slug, short_description,
                        is_open_source, license, family_slug, variant, parameter_count,
                        hf_model_id, modalities_input, modalities_output,
                        is_active, is_featured, source_url, model_card_url,
                        context_window, architecture,
                        created_at, updated_at
                    ) VALUES (
                        %(name)s, %(slug)s, %(provider)s, %(provider_slug)s, %(short_description)s,
                        %(is_open_source)s, %(license)s, %(family_slug)s, %(variant)s, %(parameter_count)s,
                        %(hf_model_id)s, %(modalities_input)s, %(modalities_output)s,
                        %(is_active)s, %(is_featured)s, %(source_url)s, %(model_card_url)s,
                        %(context_window)s, %(architecture)s,
                        %(created_at)s, %(updated_at)s
                    )
                    ON CONFLICT (slug) DO UPDATE SET
                        name = EXCLUDED.name,
                        provider = EXCLUDED.provider,
                        provider_slug = EXCLUDED.provider_slug,
                        short_description = EXCLUDED.short_description,
                        family_slug = EXCLUDED.family_slug,
                        variant = EXCLUDED.variant,
                        parameter_count = EXCLUDED.parameter_count,
                        hf_model_id = EXCLUDED.hf_model_id,
                        modalities_input = EXCLUDED.modalities_input,
                        is_featured = EXCLUDED.is_featured,
                        context_window = EXCLUDED.context_window,
                        architecture = EXCLUDED.architecture,
                        updated_at = EXCLUDED.updated_at
                """, {
                    **m,
                    "modalities_input": m.get("modalities_input", ["text"]),
                    "modalities_output": m.get("modalities_output", ["text"]),
                    "created_at": now,
                    "updated_at": now,
                })
                saved += 1
                print(f"  ✅ {m['slug']}")
            except Exception as e:
                errors.append((m.get('slug', '?'), str(e)))
                conn.rollback()
                print(f"  ❌ {m.get('slug', '?')}: {e}")
                # reconnect after rollback
                conn = psycopg2.connect(env['DATABASE_URL'])

    conn.commit()

    # Get total in DB
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM ai_models")
        total_in_db = cur.fetchone()[0]

    conn.close()

    print(f"\n📊 Saved {saved}/{len(models)} this batch. Total in DB: {total_in_db}.")
    if errors:
        print(f"❌ Errors ({len(errors)}):")
        for slug, err in errors:
            print(f"   {slug}: {err}")


if __name__ == "__main__":
    main()
