#!/usr/bin/env python3
"""
Update title and description in a Next.js TSX page metadata export.
Updates: top-level title/description, openGraph.title/description, twitter.title/description.

Usage:
  python3 update_tsx_metadata.py <slug> --title "New Title" --description "New description"

Slug map:
  homepage  → src/app/page.tsx
  openclaw  → src/app/openclaw/page.tsx
  blog      → src/app/blog/page.tsx

Prints diff of changed lines. Exits 1 if nothing changed.
"""

import sys, os, re, argparse
import skill_config

_cfg = skill_config.load()
BASE = _cfg["repo_path"]
SLUG_MAP = _cfg.get("tsx_pages", {
    "homepage": "src/app/page.tsx",
    "openclaw": "src/app/openclaw/page.tsx",
    "blog":     "src/app/blog/page.tsx",
})
LOCKED_PREFIXES = _cfg.get("locked_title_prefixes", {})

def update_tsx_metadata(slug, new_title, new_description):
    if slug not in SLUG_MAP:
        print(f"ERROR: Unknown slug '{slug}'. Known: {list(SLUG_MAP.keys())}", file=sys.stderr)
        sys.exit(1)

    # Enforce locked prefix
    if slug in LOCKED_PREFIXES:
        required = LOCKED_PREFIXES[slug]
        if not new_title.startswith(required):
            print(f"ERROR: Title for '{slug}' must start with '{required}'", file=sys.stderr)
            sys.exit(1)

    path = os.path.join(BASE, SLUG_MAP[slug])
    with open(path) as f:
        content = f.read()
    original = content

    def replace_string_field(text, key, new_val):
        """Replace value in: key: "old" or key:\n    "old" patterns."""
        # Handles both inline and multiline (description split over lines)
        pattern = rf'({re.escape(key)}:\s*(?:\n\s*)?["\'])([^"\']*?)(["\'])'
        return re.sub(pattern, lambda m: m.group(1) + new_val + m.group(3), text)

    # Update all title/description occurrences in the file
    # (covers metadata root, openGraph, twitter sections)
    content = replace_string_field(content, "title", new_title)
    content = replace_string_field(content, "description", new_description)

    if content == original:
        print("WARNING: No changes made — check field format", file=sys.stderr)
        sys.exit(1)

    with open(path, "w") as f:
        f.write(content)

    orig_lines = original.splitlines()
    new_lines = content.splitlines()
    changed = 0
    for i, (a, b) in enumerate(zip(orig_lines, new_lines)):
        if a != b:
            print(f"Line {i+1}:")
            print(f"  - {a.strip()}")
            print(f"  + {b.strip()}")
            changed += 1

    print(f"\nUpdated {changed} lines in: {path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("slug", help="Page slug: homepage, openclaw, blog")
    parser.add_argument("--title", required=True)
    parser.add_argument("--description", required=True)
    args = parser.parse_args()
    update_tsx_metadata(args.slug, args.title, args.description)
