#!/usr/bin/env python3
"""
run_scripts.py — Try to execute each bundled script in an isolated temp dir.
                 Captures stdout/stderr, cleans up. Reads /tmp/skill_audit_fetch.json.
                 Writes /tmp/skill_audit_run.json.

Usage: python3 run_scripts.py
"""

import json, os, sys, subprocess, tempfile, shutil
from pathlib import Path

fetch_data = json.loads(Path("/tmp/skill_audit_fetch.json").read_text())
scripts = fetch_data.get("scripts", {})

results = {}

if not scripts:
    Path("/tmp/skill_audit_run.json").write_text(json.dumps({
        "run_tested": False,
        "reason": "no scripts bundled",
        "results": {}
    }, indent=2))
    print("No scripts to run.")
    sys.exit(0)

tmpdir = tempfile.mkdtemp(prefix="skill_audit_")

try:
    for fname, content in scripts.items():
        script_path = Path(tmpdir) / fname
        script_path.write_text(content)

        ext = Path(fname).suffix.lower()
        if ext == ".py":
            cmd = [sys.executable, str(script_path)]
        elif ext == ".sh":
            cmd = ["bash", str(script_path)]
        else:
            results[fname] = {
                "skipped": True,
                "reason": f"unknown extension: {ext}"
            }
            continue

        try:
            proc = subprocess.run(
                cmd,
                cwd=tmpdir,
                capture_output=True,
                text=True,
                timeout=30,
                env={**os.environ, "DRY_RUN": "1", "CI": "1"}
            )
            results[fname] = {
                "exit_code": proc.returncode,
                "stdout": proc.stdout[:2000],
                "stderr": proc.stderr[:2000],
                "succeeded": proc.returncode == 0,
            }
        except subprocess.TimeoutExpired:
            results[fname] = {
                "exit_code": None,
                "succeeded": False,
                "error": "timed out after 30s"
            }
        except FileNotFoundError as e:
            results[fname] = {
                "exit_code": None,
                "succeeded": False,
                "error": f"interpreter not found: {e}"
            }
        except Exception as e:
            results[fname] = {
                "exit_code": None,
                "succeeded": False,
                "error": str(e)
            }
finally:
    shutil.rmtree(tmpdir, ignore_errors=True)

any_succeeded = any(r.get("succeeded") for r in results.values() if not r.get("skipped"))
output = {
    "run_tested": True,
    "run_succeeded": any_succeeded,
    "results": results,
}
Path("/tmp/skill_audit_run.json").write_text(json.dumps(output, indent=2))
print(f"Ran {len(results)} script(s). Succeeded: {any_succeeded}")
for fname, r in results.items():
    status = "✓" if r.get("succeeded") else ("⚠ skipped" if r.get("skipped") else "✗")
    print(f"  {status} {fname}")
