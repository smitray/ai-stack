# Open WebUI - Research Notes

**Last Updated:** March 18, 2026

---

## Overview

Open WebUI is a self-hosted web interface for LLMs. In ai-stack, it serves as the **primary user-facing chat UI**, connecting exclusively to LiteLLM as its backend.

---

## Architecture

Three-tier:
1. **Frontend** -- SvelteKit (served from container)
2. **Backend** -- FastAPI (Python)
3. **Data Layer** -- SQLite or PostgreSQL + Vector DB

---

## Integration with ai-stack

### Backend Connection

Open WebUI → LiteLLM (localhost:4000) → local llama.cpp OR cloud APIs

```
OPENAI_API_BASE_URL=http://litellm:4000/v1
OPENAI_API_KEY=${LITELLM_MASTER_KEY}
```

- Open WebUI calls LiteLLM's `/v1/models` → gets all configured models
- User picks model in dropdown → request routed through LiteLLM
- No direct connection to llama.cpp or cloud APIs
- No Ollama integration (not used)

### Database

Two options:
1. **SQLite** (default) -- stored in `/app/backend/data/webui.db`
2. **PostgreSQL** (external) -- via `DATABASE_URL` env var

**Decision:** Use PostgreSQL (shared with LiteLLM) to keep data persistent and avoid SQLite file management in containers.

### Vector Database (RAG)

Open WebUI supports Qdrant natively:
```
VECTOR_DB=qdrant
QDRANT_URL=http://qdrant:6333
```

Documents uploaded → chunked → embedded → stored in Qdrant → semantic search at query time.

### Web Search

Open WebUI has its own SearXNG integration:
```
ENABLE_WEB_SEARCH=true
WEB_SEARCH_ENGINE=searxng
SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>
```

Note: Both Open WebUI AND LiteLLM can integrate with SearXNG. Open WebUI's integration is at the UI level (user triggers search), while LiteLLM's is at the API level (tool calls). Both can coexist.

---

## Features Used in ai-stack

| Feature | Status | Notes |
|---------|--------|-------|
| Chat UI | Primary use | Model selection via LiteLLM |
| RAG (document upload) | Phase 1 | Via Qdrant vector DB |
| Web search | Phase 1 | Via SearXNG |
| Tool/function calling | Phase 1 | Built-in tools + custom |
| Image generation | Phase 2 | Via ComfyUI or API |
| Auth/user mgmt | Simplified | Single user, can disable auth |
| MCP tools | Future | External tool servers |

---

## Deployment: Podman Container

```yaml
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    ports:
      - "3000:8080"
    volumes:
      - open-webui-data:/app/backend/data
    environment:
      - OPENAI_API_BASE_URL=http://litellm:4000/v1
      - OPENAI_API_KEY=${LITELLM_MASTER_KEY}
      - DATABASE_URL=postgresql://openwebui:password@postgres:5432/openwebui
      - VECTOR_DB=qdrant
      - QDRANT_URL=http://qdrant:6333
      - ENABLE_WEB_SEARCH=true
      - WEB_SEARCH_ENGINE=searxng
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
      - WEBUI_AUTH=false  # Single user, no auth needed
    depends_on:
      - litellm
      - postgres
      - qdrant
      - searxng
```

### Persisted Volume: `/app/backend/data`
Contains:
- `uploads/` -- user-uploaded files
- `cache/` -- model/embedding cache
- `vector_db/` -- only if using built-in ChromaDB (not needed with Qdrant)

---

## Resource Requirements

| Resource | Estimate |
|----------|----------|
| RAM | ~300-500 MB |
| CPU | Low (serves UI, proxies requests) |
| Disk | Depends on uploads |
| GPU | None |
