"""Quality gates and manifest detection for MCP discovery."""

import json, time

# Server signals — patterns that indicate a real MCP server (any language)
SERVER_SIGNALS = [
    # TypeScript/Node
    "server.tool(", "server.resource(", "new McpServer", "ListToolsResult", "CallToolResult",
    # Python
    "FastMCP", "@mcp.tool", "mcp.server", "from mcp import", "from mcp.server",
    # Go
    "mcp.NewServer", "server.AddTool", "mcp.NewTool",
    # Rust
    "#[tool]", "McpServer::new",
    # Java/Kotlin
    "@Tool", "McpServer.sync", "McpServer.async",
    # C#
    "[McpServerToolType]", "McpServerTool",
]


def fetch_project_manifest(gh, owner: str, repo_name: str, branch: str) -> dict:
    """Fetch project manifest — tries multiple package formats.
    Returns dict with 'kind' and content."""

    # Node/TS
    pkg_text = gh.fetch_file(owner, repo_name, "package.json", branch)
    if pkg_text:
        try:
            return {"kind": "npm", "raw": pkg_text, "parsed": json.loads(pkg_text)}
        except Exception:
            pass

    # Python — pyproject.toml
    time.sleep(0.3)
    pyproject = gh.fetch_file(owner, repo_name, "pyproject.toml", branch)
    if pyproject:
        return {"kind": "pyproject", "raw": pyproject, "parsed": {}}

    # Python — requirements.txt
    time.sleep(0.3)
    reqs = gh.fetch_file(owner, repo_name, "requirements.txt", branch)
    if reqs:
        return {"kind": "requirements", "raw": reqs, "parsed": {}}

    # Go
    time.sleep(0.3)
    gomod = gh.fetch_file(owner, repo_name, "go.mod", branch)
    if gomod:
        return {"kind": "gomod", "raw": gomod, "parsed": {}}

    # Rust
    time.sleep(0.3)
    cargo = gh.fetch_file(owner, repo_name, "Cargo.toml", branch)
    if cargo:
        return {"kind": "cargo", "raw": cargo, "parsed": {}}

    return {"kind": None, "raw": "", "parsed": {}}


def has_mcp_sdk(manifest: dict) -> tuple[bool, str]:
    """Check if a project manifest contains an MCP SDK dependency.
    Returns (has_sdk, language)."""
    kind = manifest["kind"]
    raw = manifest["raw"]

    if kind == "npm":
        pkg = manifest["parsed"]
        all_deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
        if "@modelcontextprotocol/sdk" in all_deps:
            return True, "node"
        if "@modelcontextprotocol/ext-apps" in all_deps:
            return True, "node-apps"
        return False, ""

    if kind == "pyproject":
        if "mcp" in raw and ("fastmcp" in raw.lower() or '"mcp"' in raw or "'mcp'" in raw
                             or "mcp[" in raw or "mcp>" in raw or "mcp=" in raw):
            return True, "python"
        return False, ""

    if kind == "requirements":
        for line in raw.splitlines():
            line = line.strip().lower()
            if line.startswith("mcp") and (line == "mcp" or line.startswith("mcp[")
                                            or line.startswith("mcp>") or line.startswith("mcp=")):
                return True, "python"
            if "fastmcp" in line:
                return True, "python"
        return False, ""

    if kind == "gomod":
        if "mcp-go" in raw or "mark3labs/mcp" in raw:
            return True, "go"
        return False, ""

    if kind == "cargo":
        if "rmcp" in raw:
            return True, "rust"
        return False, ""

    return False, ""


def quality_gate_apps(repo: dict, manifest: dict, readme: str | None) -> tuple[bool, str]:
    """Gate for MCP Apps: must have ui:// signal."""
    if not readme or len(readme.strip()) < 200:
        return False, "readme missing or too short"
    if manifest["kind"] != "npm":
        return False, "no package.json (apps are JS/TS only)"
    pkg = manifest["parsed"]
    all_deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
    has_ext  = "@modelcontextprotocol/ext-apps" in all_deps
    has_uri  = "ui://" in readme or "ui://" in manifest["raw"]
    if not has_ext and not has_uri:
        return False, "no MCP App signal (no ext-apps dep or ui:// pattern)"
    stars = repo.get("stargazers_count", 0)
    npm   = pkg.get("name", "")
    is_published = bool(npm) and not any(npm.startswith(p) for p in ["my-", "template", "starter"])
    if stars == 0 and not is_published:
        return False, "0 stars and not published"
    name_lower = repo.get("name", "").lower()
    if any(s in name_lower for s in ["template", "example", "starter", "boilerplate"]) and stars < 5:
        return False, "template/example with low stars"
    return True, "ok"


def quality_gate_servers(repo: dict, manifest: dict, readme: str | None) -> tuple[bool, str]:
    """Gate for MCP Servers: must have MCP SDK in any language."""
    if not readme or len(readme.strip()) < 200:
        return False, "readme missing or too short"
    if not manifest["kind"]:
        return False, "no project manifest found"

    sdk_found, sdk_lang = has_mcp_sdk(manifest)
    if not sdk_found:
        return False, f"no MCP SDK found in {manifest['kind']}"

    # Must not be a pure MCP App
    if sdk_lang == "node-apps":
        return False, "has ext-apps dep — belongs in apps mode"
    if "ui://" in readme:
        return False, "has ui:// signals — belongs in apps mode"

    # Check for server signals in readme or manifest
    has_tools = any(sig in readme for sig in SERVER_SIGNALS)
    if not has_tools:
        has_tools = any(sig in manifest["raw"] for sig in SERVER_SIGNALS)

    stars = repo.get("stargazers_count", 0)
    if stars == 0 and not has_tools:
        return False, "0 stars and no tool definitions found"
    name_lower = repo.get("name", "").lower()
    if any(s in name_lower for s in ["template", "example", "starter", "boilerplate"]) and stars < 5:
        return False, "template/example with low stars"
    return True, "ok"
