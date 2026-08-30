---
name: web-search
description: Search the web with DuckDuckGo (ddgr) and get JSON results. Use when a task needs current or unknown information — package versions, library APIs, error messages, documentation, news, or anything not answerable from local files.
---

# Web Search

Search the web via DuckDuckGo. The wrapper script is self-contained (ddgr is
bundled), so it works from any directory.

## Usage

```bash
./scripts/web-search "query words here"
```

Relative to this skill's directory; resolve it from the path you read this
file from. Equivalent absolute path: `~/.pi/agent/skills/web-search/scripts/web-search`.

Output is a JSON array of results, newest-relevance first:

```json
[{ "title": "...", "url": "...", "abstract": "..." }]
```

Default 5 results; pass more with `-n` (up to 25):

```bash
./scripts/web-search -n 10 "rust async runtime comparison"
```

Any other ddgr flags pass through, e.g.:

- `-t w` — restrict to last week (use `d`/`m`/`y` for day/month/year)
- `-w site` — restrict to a site (`-w nixos.org` style: put it before the query)
- `--unsafe` — disable safe search (rarely needed)

## Agent guidance

- Prefer 3–5 results; fetch more only if the first batch is unhelpful.
- Follow up interesting `url`s by fetching the page (e.g. `curl -sL`), not by
  re-searching with different words immediately.
- Queries are plain keywords — strip punctuation and filler words.
