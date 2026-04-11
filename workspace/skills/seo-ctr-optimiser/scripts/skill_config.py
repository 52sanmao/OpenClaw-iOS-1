#!/usr/bin/env python3
"""
Shared config loader for seo-ctr-optimiser scripts.
Config file: ~/.config/seo-ctr-optimiser/config.json

If config doesn't exist, copies the example from the skill's references/ dir
and exits with instructions to edit it.
"""

import json, os, sys

CONFIG_PATH = os.path.expanduser("~/.config/seo-ctr-optimiser/config.json")
EXAMPLE_PATH = os.path.join(os.path.dirname(__file__), "../references/config.example.json")

def load():
    if not os.path.exists(CONFIG_PATH):
        os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
        import shutil
        shutil.copy(os.path.abspath(EXAMPLE_PATH), CONFIG_PATH)
        print(f"⚠️  Config created at {CONFIG_PATH}", file=sys.stderr)
        print(f"   Edit it for this client, then re-run.", file=sys.stderr)
        sys.exit(1)
    with open(CONFIG_PATH) as f:
        cfg = json.load(f)
    # Expand ~ in paths
    for key in ("repo_path",):
        if key in cfg:
            cfg[key] = os.path.expanduser(cfg[key])
    return cfg
