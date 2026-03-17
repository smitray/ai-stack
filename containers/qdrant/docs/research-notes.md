# Qdrant - Research Notes

**Last Updated:** March 18, 2026

---

## Overview

Qdrant is a vector similarity search engine. In ai-stack, it serves as the **vector database for RAG** -- storing document embeddings for semantic search. Open WebUI sends vectors to Qdrant and queries it during retrieval.

**Important:** Qdrant does NOT generate embeddings. Clients (Open WebUI) provide pre-computed vectors. Open WebUI handles embedding generation using its configured embedding model.

---

## Deployment: Podman Container

```yaml
services:
  qdrant:
    image: docker.io/qdrant/qdrant:latest
    ports:
      - "6333:6333"   # HTTP REST API
      - "6334:6334"   # gRPC API
    volumes:
      - qdrant-storage:/qdrant/storage
      - qdrant-snapshots:/qdrant/snapshots
```

### Volumes
- `/qdrant/storage` -- All persistent data (collections, vectors, indexes)
- `/qdrant/snapshots` -- Collection snapshots/backups

### Ports
- `6333` -- HTTP REST API
- `6334` -- gRPC API

---

## Configuration

Custom config via `production.yaml` mounted at `/qdrant/config/production.yaml`:

```yaml
storage:
  on_disk_payload: true    # Save RAM: payloads stored on disk
  wal:
    wal_capacity_mb: 32    # Reduced for personal use

optimizers:
  indexing_threshold_kb: 20000

# For personal use, single-node is fine
cluster:
  enabled: false
```

### Key Config Options

| Setting | Default | Personal Use |
|---------|---------|-------------|
| `on_disk_payload` | false | `true` (saves RAM) |
| `wal_capacity_mb` | 32 | 32 (fine) |
| `indexing_threshold_kb` | 20000 | 20000 (fine) |

---

## Integration with Open WebUI

```
VECTOR_DB=qdrant
QDRANT_URL=http://qdrant:6333
```

Open WebUI handles:
1. Document upload → chunking → embedding generation
2. Storing vectors in Qdrant collections
3. Querying Qdrant for semantic search during RAG

---

## REST API Basics

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Create collection | PUT | `/collections/{name}` |
| Add points | PUT | `/collections/{name}/points` |
| Search | POST | `/collections/{name}/points/search` |
| List collections | GET | `/collections` |
| Delete collection | DELETE | `/collections/{name}` |

---

## Resource Requirements

| Resource | Estimate (Personal Use) |
|----------|------------------------|
| RAM | ~100-300 MB (with on_disk_payload) |
| CPU | Low (single-user queries) |
| Disk | Depends on documents indexed |
| GPU | None |
