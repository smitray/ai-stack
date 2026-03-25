# SearXNG - Research Notes

**Last Updated:** March 19, 2026  
**Note:** LiteLLM removed - updated integration info

---

## Overview

SearXNG is a privacy-respecting metasearch engine. In ai-stack, it serves as the **web search backend** for Open WebUI (UI-level search).

**Previously:** Also used by LiteLLM (removed) for API-level tool calls.

---

## Deployment: Podman Container

```yaml
services:
  searxng:
    image: docker.io/searxng/searxng:latest
    ports:
      - "8888:8080"
    volumes:
      - ./searxng/config:/etc/searxng:rw
      - searxng-data:/var/cache/searxng
    environment:
      - SEARXNG_BASE_URL=http://localhost:8888
```

### Volumes
- `/etc/searxng/` -- Configuration files (`settings.yml`, `uwsgi.ini`)
- `/var/cache/searxng/` -- Persistent cache data

### Ports
- `8080` (container) → `8888` (host)

---

## Configuration

### settings.yml

```yaml
use_default_settings: true

general:
  instance_name: "ai-stack search"

server:
  secret_key: "<generated-key>"  # openssl rand -hex 16
  limiter: true                   # Rate limiting (requires Valkey)
  image_proxy: true

search:
  safe_search: 0
  autocomplete: "google"
  default_lang: "en"

# Valkey integration for rate limiting
valkey:
  url: redis://valkey:6379/0

# Engine customization
engines:
  - name: google
    disabled: false
  - name: duckduckgo
    disabled: false
  - name: wikipedia
    disabled: false
  - name: github
    disabled: false
  - name: stackoverflow
    disabled: false
  - name: arch wiki
    disabled: false
```

### API Endpoints

- `GET /search?q=<query>&format=json` -- JSON results
- `GET /search?q=<query>&format=csv` -- CSV results
- `GET /search?q=<query>&format=rss` -- RSS results

Parameters: `q`, `categories`, `engines`, `language`, `pageno`, `time_range`

---

## Integration Points

### With Open WebUI
```
ENABLE_WEB_SEARCH=true
WEB_SEARCH_ENGINE=searxng
SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>
```

### With LiteLLM
```yaml
litellm_settings:
  search_tools:
    - tool_name: "web_search"
      provider: "searxng"
      api_base: "http://searxng:8080"
```

### With Valkey (rate limiting)
SearXNG uses Valkey for its built-in rate limiter. Same Valkey instance used by LiteLLM for caching.

---

## Resource Requirements

| Resource | Estimate |
|----------|----------|
| RAM | ~100-200 MB |
| CPU | Low (proxies to search engines) |
| Disk | Minimal (cache only) |
| GPU | None |
| Network | Needs internet access for search queries |
