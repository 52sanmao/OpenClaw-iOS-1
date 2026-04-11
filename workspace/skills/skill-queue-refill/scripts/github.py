"""GitHub API client with rate-limit-aware pacing."""

import base64, time, sys
import requests

# Minimum remaining calls before we start slowing down
RATE_LIMIT_BUFFER = 50
# How long to sleep when rate limit is low
RATE_LIMIT_BACKOFF = 10


class GitHubClient:
    def __init__(self, token: str):
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        self._remaining: int | None = None
        self._reset_at: float | None = None

    def _update_rate_limit(self, resp: requests.Response):
        """Track rate limit from response headers."""
        remaining = resp.headers.get("X-RateLimit-Remaining")
        reset = resp.headers.get("X-RateLimit-Reset")
        if remaining is not None:
            self._remaining = int(remaining)
        if reset is not None:
            self._reset_at = float(reset)

    def _pace(self):
        """Sleep if we're running low on rate limit."""
        if self._remaining is None:
            return
        if self._remaining <= 0 and self._reset_at:
            wait = max(0, self._reset_at - time.time()) + 1
            print(f"  rate limit exhausted, waiting {wait:.0f}s", file=sys.stderr, flush=True)
            time.sleep(wait)
        elif self._remaining < RATE_LIMIT_BUFFER:
            print(f"  rate limit low ({self._remaining} left), slowing down", file=sys.stderr, flush=True)
            time.sleep(RATE_LIMIT_BACKOFF)

    def code_search(self, query: str, sort: str = "indexed", order: str = "desc", page: int = 1) -> list[dict]:
        """Fetch one page of code search results."""
        self._pace()
        params = {"q": query, "per_page": 100, "sort": sort, "order": order, "page": page}
        resp = requests.get(
            "https://api.github.com/search/code",
            headers=self.headers, params=params, timeout=15,
        )
        self._update_rate_limit(resp)
        if resp.status_code in (403, 422):
            return []
        resp.raise_for_status()
        return resp.json().get("items", [])

    def fetch_file(self, owner: str, repo: str, path: str, branch: str = "main") -> str | None:
        """Fetch file content via Contents API. Tries branch, main, master (deduped)."""
        refs = list(dict.fromkeys([branch, "main", "master"]))
        for ref in refs:
            self._pace()
            resp = requests.get(
                f"https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={ref}",
                headers=self.headers, timeout=15,
            )
            self._update_rate_limit(resp)
            if resp.status_code == 200:
                data = resp.json()
                if data.get("encoding") == "base64":
                    try:
                        return base64.b64decode(data["content"]).decode("utf-8", errors="replace")
                    except Exception:
                        return None
        return None

    def fetch_repo(self, owner: str, repo: str) -> dict | None:
        """Fetch repository metadata."""
        self._pace()
        resp = requests.get(
            f"https://api.github.com/repos/{owner}/{repo}",
            headers=self.headers, timeout=15,
        )
        self._update_rate_limit(resp)
        return resp.json() if resp.status_code == 200 else None

    @property
    def remaining(self) -> int | None:
        return self._remaining


def raw_url(owner: str, repo: str, path: str, branch: str = "main") -> str:
    return f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}"
