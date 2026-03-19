# Hugging Face CLI - Model Management Guide

## Overview

Hugging Face provides a unified CLI tool (`hf`) that serves as the **single source of truth** for all model downloads. Models are cached centrally and automatically reused across libraries.

## Installation

```bash
pip install -U "huggingface_hub[cli]"
```

## Authentication

Login with your Hugging Face token (stored in `~/.env`):

```bash
hf auth login --token $HF_TOKEN
```

## Cache Location

Default cache directory:
```
~/.cache/huggingface/hub/
```

Customizable via environment variables:
```bash
export HF_HOME=~/.cache/huggingface
export HF_HUB_CACHE=~/.cache/huggingface/hub
```

## Downloading Models

### Download Single Model (STT)

```bash
# Downloads to HF cache, returns path
hf download deepdml/faster-whisper-large-v3-turbo-ct2
```

### Download GGUF Model (LLM)

```bash
# Download specific quantization
hf download unsloth/Qwen3.5-4B-GGUF Q4_K_M.gguf

# Download entire repo
hf download unsloth/Qwen3.5-4B-GGUF
```

### Download with Custom Cache

```bash
hf download deepdml/faster-whisper-large-v3-turbo-ct2
```

## Cache Management

### List Cached Models

```bash
# Show all cached repos with sizes
hf cache ls

# Filter by size
hf cache ls --filter "size>1GB"

# Show revisions
hf cache ls --revisions
```

### Verify Cache Integrity

```bash
hf cache verify deepdml/faster-whisper-large-v3-turbo-ct2
```

### Delete Cached Models

```bash
# Remove specific model
hf cache rm deepdml/faster-whisper-large-v3-turbo-ct2

# Interactive prune
hf cache prune
```

### Scan Cache (Python API)

```python
from huggingface_hub import scan_cache_dir

hf_cache_info = scan_cache_dir()
print(f"Total size: {hf_cache_info.size_on_disk / 1e9:.2f} GB")
print(f"Cached repos: {len(hf_cache_info.repos)}")
```

## How Libraries Use HF Cache

### faster-whisper (STT)

```python
from faster_whisper import WhisperModel

# Automatically uses HF cache
model = WhisperModel("deepdml/faster-whisper-large-v3-turbo-ct2")
```

### llama.cpp (LLM)

```bash
# llama.cpp auto-downloads from HF
llama-server -hf unsloth/Qwen3.5-4B-GGUF:Q4_K_M

# Or use cached path directly
llama-server -m ~/.cache/huggingface/hub/models--unsloth--Qwen3.5-4B-GGUF/snapshots/*/Q4_K_M.gguf
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `HF_HOME` | `~/.cache/huggingface` | Root cache directory |
| `HF_HUB_CACHE` | `~/.cache/huggingface/hub` | Model cache subdirectory |
| `HF_TOKEN` | (none) | Authentication token |
| `HF_XET_HIGH_PERFORMANCE` | `0` | Enable high-performance Xet transfers |

## Benefits of HF Cache

1. **Single Source of Truth**: One download, used everywhere
2. **Version-Aware**: Different revisions cached separately
3. **Content-Addressed**: Blobs deduplicated across models
4. **Automatic**: Libraries check cache before downloading
5. **Manageable**: CLI tools for inspection and cleanup

## Cache Structure

```
~/.cache/huggingface/hub/
├── blobs/                          # Actual file contents (content-addressed)
│   ├── 403450e234d65943a7dcf7e05a771ce3c92faa84dd07db4ac20f592037a1e4bd
│   └── ...
├── models--{org}--{name}/
│   ├── refs/
│   │   └── main                   # Git ref (points to commit hash)
│   └── snapshots/
│       └── {commit-hash}/         # Actual model files (symlinks to blobs)
│           ├── config.json
│           ├── model.safetensors
│           └── ...
└── xet/                           # Xet storage metadata (optional)
```

## Recommended Workflow

```bash
# 1. Authenticate once
hf auth login --token $HF_TOKEN

# 2. Download all required models
hf download deepdml/faster-whisper-large-v3-turbo-ct2
hf download unsloth/Qwen3.5-4B-GGUF

# 3. Verify downloads
hf cache ls

# 4. Use in applications (no further action needed)
# Applications automatically find models in cache
```
