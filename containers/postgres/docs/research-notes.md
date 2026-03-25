# PostgreSQL - Research Notes

**Last Updated:** March 19, 2026  
**Note:** LiteLLM removed - PostgreSQL now only used for Open WebUI

---

## Overview

PostgreSQL is the relational database for ai-stack. Used by **Open WebUI** for chat history and user data.

**Previously:** Also required by LiteLLM (removed) for virtual keys and spend tracking.

---

## Deployment: Podman Container

```yaml
services:
  postgres:
    image: docker.io/library/postgres:17-alpine
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=aistack
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=aistack
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U aistack"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Volumes
- `/var/lib/postgresql/data` -- All database files

### Port
- `5432` (default)

---

## Database Schema

Multiple databases (or schemas) for different services:

| Database | Used By | Purpose |
|----------|---------|---------|
| `litellm` | LiteLLM | Virtual keys, spend logs, rate limits |
| `openwebui` | Open WebUI | Chat history, user data, settings |

### Init Script

Create an init script to set up multiple databases:

```sql
-- /docker-entrypoint-initdb.d/init.sql
CREATE DATABASE litellm;
CREATE DATABASE openwebui;
CREATE USER litellm WITH PASSWORD 'litellm_pass';
CREATE USER openwebui WITH PASSWORD 'openwebui_pass';
GRANT ALL PRIVILEGES ON DATABASE litellm TO litellm;
GRANT ALL PRIVILEGES ON DATABASE openwebui TO openwebui;
```

---

## Configuration

### For Personal Use

```
shared_buffers = 128MB         # 25% of available DB RAM
effective_cache_size = 256MB
work_mem = 4MB
maintenance_work_mem = 64MB
max_connections = 20           # Low -- only 2 services connecting
```

### Connection Strings

```
# LiteLLM
DATABASE_URL=postgresql://litellm:litellm_pass@postgres:5432/litellm

# Open WebUI
DATABASE_URL=postgresql://openwebui:openwebui_pass@postgres:5432/openwebui
```

---

## Backup Strategy

Simple pg_dump via cron or systemd timer:
```bash
podman exec postgres pg_dumpall -U aistack > /srv/databases/postgres/backup-$(date +%F).sql
```

---

## Resource Requirements

| Resource | Estimate (Personal Use) |
|----------|------------------------|
| RAM | ~100-200 MB (with tuned shared_buffers) |
| CPU | Minimal (light query load) |
| Disk | < 500 MB (metadata, logs, spend data) |
| GPU | None |

---

## Why PostgreSQL over SQLite

1. LiteLLM **requires** PostgreSQL for full gateway features (virtual keys, spend tracking)
2. Open WebUI performs better with PostgreSQL for concurrent access
3. Single PostgreSQL instance serves both -- simpler than managing two SQLite files in containers
4. Proper backup/restore tooling (pg_dump, pg_restore)
5. Already planned in partition-table.md under `/srv/databases/postgres/`
