#!/usr/bin/env python3
"""
Update seo.title and seo.description in a blog post MDX frontmatter.
Also syncs top-level title/description and openGraph/twitter fields.

Usage:
  python3 update_frontmatter.py <slug> --title "New Title" --description "New description"

Prints a diff of what changed.
"""

import sys, os, re, argparse
import skill_config

_cfg = skill_config.load()
BLOG_DIR = os.path.join(_cfg["repo_path"], _cfg.get("blog_content_path", "content/blog"))

def update_frontmatter(slug, new_title, new_description):
    path = os.path.join(BLOG_DIR, f"{slug}.md")
    if not os.path.exists(path):
        print(f"ERROR: File not found: {path}", file=sys.stderr)
        sys.exit(1)

    with open(path) as f:
        content = f.read()

    original = content

    def replace_field(text, key, new_val):
        """Replace a quoted string field value, handling nested yaml keys."""
        # Match: key: "old value" or key: 'old value'
        pattern = rf'({re.escape(key)}:\s*["\'])([^"\']*?)(["\'])'
        replacement = rf'\g<1>{new_val}\g<3>'
        return re.sub(pattern, replacement, text)

    # Update all title/description occurrences
    content = replace_field(content, "title", new_title)
    content = replace_field(content, "description", new_description)

    if content == original:
        print("WARNING: No changes made — check field names/format", file=sys.stderr)
        sys.exit(1)

    with open(path, "w") as f:
        f.write(content)

    # Print simple diff
    orig_lines = original.splitlines()
    new_lines = content.splitlines()
    for i, (a, b) in enumerate(zip(orig_lines, new_lines)):
        if a != b:
            print(f"Line {i+1}:")
            print(f"  - {a.strip()}")
            print(f"  + {b.strip()}")

    print(f"\nUpdated: {path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("slug")
    parser.add_argument("--title", required=True)
    parser.add_argument("--description", required=True)
    args = parser.parse_args()
    update_frontmatter(args.slug, args.title, args.description)
