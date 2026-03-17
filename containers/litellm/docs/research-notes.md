# LiteLLM - Research Notes

**Last Updated:** March 18, 2026

---

## Overview

LiteLLM is a unified API gateway/proxy that provides an OpenAI-compatible interface to 100+ LLM providers. For ai-stack, it serves as the **central routing layer** between all consumers (Open WebUI, CLI tools, scripts) and all LLM providers (local llama.cpp + cloud APIs).

---

## Architecture Decision: Full Gateway

Running in **Proxy Server mode** with:
- PostgreSQL database (spend tracking, virtual keys)
- Valkey/Redis caching (rate limiting, API key cache, response cache)
- Full config.yaml with model routing

### Why Full Gateway (not lightweight)
- Multiple cloud APIs with different TPM/RPM limits → need rate limiting
- Want spend tracking across providers
- Need fallback: local model → cloud API
- SearXNG web search integration built-in

---

## Key Features for ai-stack

### 1. Local ↔ Cloud Routing

LiteLLM can route the same `model_name` to local llama.cpp first, falling back to cloud if local is unavailable (e.g., VRAM occupied by STT):

```yaml
model_list:
  - model_name: "default-chat"
    litellm_params:
      model: "openai/local-qwen-3b"
      api_base: "http://localhost:8080/v1"
      api_key: "sk-local"
      rpm: 10
  - model_name: "default-chat"
    litellm_params:
      model: "anthropic/claude-3-haiku-20240307"
      api_key: "os.environ/ANTHROPIC_API_KEY"
      rpm: 60

litellm_settings:
  fallbacks: [{"default-chat": ["default-chat"]}]
```

When local llama.cpp is sleeping (VRAM freed), requests fail → auto-fallback to cloud.

### 2. SearXNG Web Search Integration

LiteLLM **natively supports SearXNG** as a search provider. Configuration:

```yaml
litellm_settings:
  search_tools:
    - tool_name: "web_search"
      provider: "searxng"
      api_base: "http://localhost:8888"  # SearXNG endpoint
```

How it works:
1. LLM makes a web search tool call
2. LiteLLM intercepts it via `WebSearchInterceptionLogger`
3. Executes search against SearXNG
4. Injects results back into LLM context
5. LLM generates response with search context

### 3. Rate Limiting & Spend Tracking

Per-provider rate limits:
```yaml
model_list:
  - model_name: "gpt-4o"
    litellm_params:
      model: "openai/gpt-4o"
      api_key: "os.environ/OPENAI_API_KEY"
      rpm: 200
      tpm: 30000

router_settings:
  optional_pre_call_checks: ["enforce_model_rate_limits"]
```

Provider budget limits:
```yaml
router_settings:
  provider_budget_config:
    openai:
      budget_limit: 100.0  # $100/month
      time_period: "1m"
```

### 4. Routing Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| `simple-shuffle` | Random weighted by RPM/TPM | Default, best performance |
| `cost-based-routing` | Cheapest available provider | Minimize spend |
| `latency-based-routing` | Lowest response time | Speed-critical |
| `least-busy` | Fewest active requests | Load distribution |

### 5. Health Checking & Cooldowns

```yaml
router_settings:
  allowed_fails: 3
  cooldown_time: 60  # seconds
  retry_policy:
    TimeoutError: 2
    InternalServerError: 3
```

When local llama.cpp fails (e.g., VRAM occupied), it gets cooled down → requests route to cloud → after cooldown, tries local again.

---

## Deployment: Podman Container

```yaml
# In containers/compose.yaml
services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    ports:
      - "4000:4000"
    volumes:
      - ./litellm/config/litellm-config.yaml:/app/config.yaml
    environment:
      - DATABASE_URL=postgresql://litellm:password@postgres:5432/litellm
      - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    command: ["--config", "/app/config.yaml"]
    depends_on:
      - postgres
      - valkey
```

### Dependencies
- **PostgreSQL** -- Required for virtual keys, spend tracking
- **Valkey/Redis** -- Required for caching, rate limiting
- Both run as Podman containers alongside LiteLLM

---

## Resource Requirements

| Resource | Requirement |
|----------|-------------|
| RAM | ~200-500 MB (lightweight for personal use) |
| CPU | Minimal (proxy, not inference) |
| Disk | Minimal (logs + DB) |
| GPU | None (pure proxy) |
| Network | Needs access to localhost:8080 (llama.cpp) and internet (cloud APIs) |

---

## Implications for ai-stack

1. **Need PostgreSQL container** -- Required for LiteLLM full gateway
2. **Valkey serves double duty** -- Caching for LiteLLM + potentially other services
3. **LiteLLM is the single API endpoint** -- All consumers (Open WebUI, CLI, scripts) talk to `localhost:4000`, never directly to providers
4. **SearXNG integration is free** -- Just config, no custom code needed
5. **Local/cloud fallback solves the VRAM contention** -- When STT occupies GPU, LLM requests gracefully fall back to cloud
