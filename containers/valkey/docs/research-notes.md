# Valkey - Research Notes

**Last Updated:** March 19, 2026  
**Note:** LiteLLM removed - updated roles

---

## Overview

Valkey is a Redis-compatible in-memory data store (fork of Redis OSS). In ai-stack, it serves **multiple roles**:

1. **SearXNG rate limiter** -- Bot protection and request rate limiting
2. **Open WebUI cache** -- Response caching for better performance

**Previously:** Also used by LiteLLM (removed) for API key caching, rate limiting, and LLM response caching.

---

## Deployment: Podman Container

```yaml
services:
  valkey:
    image: docker.io/valkey/valkey:latest
    ports:
      - "6379:6379"
    volumes:
      - valkey-data:/data
    command: >
      valkey-server
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --appendonly yes
      --appendfsync everysec
      --bind 0.0.0.0
      --protected-mode no
```

### Volumes
- `/data` -- RDB dumps and AOF files

### Port
- `6379` (default, same as Redis)

---

## Configuration

### For Cache Use (LiteLLM)

```
maxmemory 256mb              # Cap memory usage
maxmemory-policy allkeys-lru # Evict least recently used keys
```

### Persistence

| Option | Setting | Purpose |
|--------|---------|---------|
| AOF | `appendonly yes` | Durability (logs every write) |
| fsync | `appendfsync everysec` | Flush to disk every second |
| RDB | Default save intervals | Periodic snapshots |

For a cache, persistence is optional but nice-to-have (survives container restarts without cold cache).

### Security (Container Network)

Inside Podman network, containers communicate directly. No password needed for local-only access. If exposing to host:
```
requirepass <password>
protected-mode yes
bind 127.0.0.1
```

---

## Redis Compatibility

Valkey is **fully compatible** with Redis clients and protocol. LiteLLM, SearXNG, and Open WebUI all use standard Redis client libraries -- they work with Valkey without changes.

Config option for edge cases:
```
extended-redis-compatibility yes  # Makes Valkey identify as Redis
```

---

## Integration Points

### LiteLLM
```yaml
# In LiteLLM config.yaml
general_settings:
  use_redis_transaction_buffer: true

litellm_settings:
  cache: true
  cache_params:
    type: redis
    host: valkey
    port: 6379
```

### SearXNG
```yaml
# In SearXNG settings.yml
valkey:
  url: redis://valkey:6379/0
```

### Open WebUI (optional)
```
REDIS_URL=redis://valkey:6379/1
```

Using different Redis databases (0, 1, etc.) to namespace per service.

---

## Resource Requirements

| Resource | Estimate |
|----------|----------|
| RAM | 256 MB max (capped by maxmemory) |
| CPU | Minimal (single-threaded for commands) |
| Disk | < 100 MB (cache data + AOF) |
| GPU | None |
