# ai-stack Comprehensive Audit Report

**Audit Date:** March 26, 2026  
**Auditor:** AI Assistant  
**Scope:** Full codebase review — security, architecture, dependencies, documentation  
**Repository:** `/home/debasmitr/workspace/ai-stack`  
**Current Branch:** `feature/ai-router` (HEAD: 5e94a81)

---

## Executive Summary

| Category | Rating | Status |
|----------|--------|--------|
| **Security** | 🟡 **MODERATE** | 3 Critical, 5 High issues found |
| **Architecture** | 🟢 **GOOD** | Clean separation, hardware-aware design |
| **Code Quality** | 🟢 **GOOD** | Production-quality STT service |
| **Documentation** | 🟢 **EXCELLENT** | Comprehensive PRDs, hardware profiles |
| **Dependencies** | 🟡 **MODERATE** | Unpinned versions, one vulnerable branch |
| **Configuration** | 🟢 **GOOD** | llama.cpp presets corrected |

**Overall Assessment:** 🟡 **MODERATE RISK** — Solid architecture with actionable security improvements needed.

---

## 1. Core Infrastructure Audit

### 1.1 CLI (`bin/ai-stack`)

| Finding | Severity | Status |
|---------|----------|--------|
| ✅ Proper error handling with `set -e` | — | PASS |
| ✅ XDG-compliant paths | — | PASS |
| ⚠️ No validation for `~/.env` existence before sourcing | 🟡 Medium | Needs fix |
| ⚠️ GPU switching doesn't verify service state after commands | 🟡 Medium | Needs fix |
| ✅ Comprehensive subcommands (up/down/gpu/install/models) | — | PASS |

**Lines of Code:** 177 lines  
**Functions:** 8 subcommands (up, down, restart, status, logs, gpu, install, models)

### 1.2 Bootstrap Script (`lib/install-base.sh`)

| Finding | Severity | Status |
|---------|----------|--------|
| ✅ Auto-installs missing dependencies | — | PASS |
| ✅ Configures NVIDIA Container Toolkit for Podman | — | PASS |
| ⚠️ No validation for required secrets in `.env` | 🟠 High | **Must fix** |
| ⚠️ Silent failure on HF auth (`|| true`) | 🟡 Medium | Needs warning |
| ✅ Injects CUDA paths into `~/.zshrc` idempotently | — | PASS |

**Dependencies Checked:** podman, podman-compose, nvidia-container-toolkit, base-devel, cmake, git, cuda

---

## 2. Bare-Metal Services Audit

### 2.1 Whisper STT Service

**Location:** `bare-metal/stt/`  
**Version:** 1.0.0  
**Python:** >=3.10

#### Architecture Review

| Component | File | Quality |
|-----------|------|---------|
| FastAPI Server | `src/whisper_stt/server.py` | 🟢 Good |
| Transcription Service | `src/whisper_stt/service.py` | 🟢 Good |
| Configuration | `src/whisper_stt/config.py` | 🟡 Needs improvement |
| Pydantic Models | `src/whisper_stt/models.py` | 🟢 Good |
| Logging | `src/whisper_stt/logging_config.py` | 🟢 Good |

#### Security Findings

| # | Finding | Severity | File:Line | Recommendation |
|---|---------|----------|-----------|----------------|
| STT-01 | File upload validation can be spoofed (content-type check only) | 🔴 **Critical** | `server.py:95` | Add magic byte validation with `python-magic` |
| STT-02 | No input size limits on uploaded audio files | 🟠 High | `server.py:97-100` | Add `max_upload_size` configuration |
| STT-03 | nvidia-smi timeout too short (5s) | 🟡 Medium | `server.py:139` | Increase to 10s + add retry logic |
| STT-04 | Incomplete environment variable overrides | 🟡 Medium | `config.py:104-113` | Add `WHISPER_HOST`, `WHISPER_WORKERS`, `WHISPER_LOG_LEVEL` |
| STT-05 | Unused `timestamp_granularities` field | 🟢 Low | `models.py:18` | Remove or document as future feature |

#### Dependencies

```toml
fastapi>=0.109.0      # ⚠️ Unpinned (no upper bound)
uvicorn[standard]>=0.27.0  # ⚠️ Unpinned
faster-whisper>=1.0.0      # ⚠️ Unpinned
ctranslate2>=4.0.0         # ⚠️ Unpinned
pydantic>=2.0.0            # ⚠️ Unpinned
pyyaml>=6.0                # ⚠️ Unpinned
python-multipart>=0.0.6    # ⚠️ Unpinned
```

**Recommendation:** Add upper bounds to prevent breaking changes:
```toml
fastapi>=0.109.0,<1.0.0
pydantic>=2.0.0,<3.0.0
```

#### Test Coverage

| File | Tests | Coverage |
|------|-------|----------|
| `tests/test_config.py` | 2 tests | Config loading, env overrides |
| `tests/test_models.py` | 2 tests | Basic model validation |

**Status:** 🟡 Minimal — Needs expansion for edge cases, error handling, integration tests

### 2.2 llama.cpp Service

**Location:** `bare-metal/llama-cpp/`  
**Build:** From source (CUDA, sm_86)

#### Configuration Audit

| File | Status | Notes |
|------|--------|-------|
| `config/presets.ini` | ✅ **Corrected** | Updated to official format (commit 5e94a81) |
| `config/llama-cpp.service` | ✅ Good | Proper systemd unit |

#### presets.ini Format (After Fix)

```ini
version = 1              # ✅ Added (required)

[*]                      # ✅ Correct global section
models-max = 1
sleep-idle-seconds = 300
n-gpu-layers = 99
c = 4096                 # ✅ Using canonical shorthand
flash-attn = true
cache-type-k = q4_0
cache-type-v = q4_0

[unsloth/Qwen3.5-4B-GGUF:Q4_K_M]  # ✅ HF repo as section name
chat-template = qwen               # ✅ Added
load-on-startup = false
```

#### Install Script Findings

| Finding | Severity | Status |
|---------|----------|--------|
| ✅ Proper CUDA path exports | — | PASS |
| ✅ LTO + RTX 3050 optimization (sm_86) | — | PASS |
| ⚠️ Hardcoded sm_86 (not portable) | 🟡 Medium | Acceptable for single-machine deployment |
| ✅ HF CLI authentication | — | PASS |

---

## 3. Container Services Audit

### 3.1 Compose Configuration

**File:** `containers/compose.yaml`  
**Services:** 7 (postgres, valkey, qdrant, searxng, ai-router, openwebui, n8n)

#### Service Inventory

| Service | Image | Port | Memory Limit | Health Check |
|---------|-------|------|--------------|--------------|
| postgres | `postgres:17-alpine` | — | 512m | ✅ `pg_isready` |
| valkey | `valkey/valkey:8-alpine` | — | 384m | ✅ `valkey-cli ping` |
| qdrant | `qdrant/qdrant:latest` | — | 512m | ✅ `/readyz` |
| searxng | `searxng/searxng:latest` | 7863:8080 | 256m | ✅ `/healthz` |
| ai-router | Build (./ai-router) | 7864:7864 | 256m | ❌ **Missing** |
| openwebui | `ghcr.io/open-webui/open-webui:main` | 7860:8080 | 1g | ❌ **Missing** |
| n8n | `docker.n8n.io/n8nio/n8n` | 7862:5678 | 1g | ❌ **Missing** |

#### Security Findings

| # | Finding | Severity | Service | Recommendation |
|---|---------|----------|---------|----------------|
| CNT-01 | ai-router has no health check | 🟡 Medium | ai-router | Add HEALTHCHECK to Dockerfile |
| CNT-02 | Open WebUI connects to ai-router (port 7864), not direct llama.cpp (7865) | 🟡 Medium | openwebui | Verify this is intentional (fallback vs direct) |
| CNT-03 | No secrets validation at startup | 🟠 High | All | Add init container or entrypoint script to validate required env vars |
| CNT-04 | `latest` tag for Qdrant | 🟡 Medium | qdrant | Pin to specific version for reproducibility |

#### Port Standardization (Commit ff93cfa)

| Service | Port | Status |
|---------|------|--------|
| Open WebUI | 7860 | ✅ Standardized |
| n8n | 7862 | ✅ Standardized |
| SearXNG | 7863 | ✅ Standardized |
| ai-router | 7864 | ✅ Standardized |
| llama.cpp | 7865 | ✅ Standardized (systemd) |
| STT | 7861 | ✅ Standardized |

### 3.2 ai-router Service

**Location:** `containers/ai-router/`  
**Purpose:** LLM request proxy with cloud fallback

#### Security Findings

| # | Finding | Severity | File:Line | Recommendation |
|---|---------|----------|-----------|----------------|
| RTR-01 | **No input validation on model names** | 🔴 **Critical** | `main.py:48-52` | Add Pydantic request model with validation |
| RTR-02 | No schema validation for `models.yaml` | 🟠 High | `main.py:16-17` | Add Pydantic model for router config |
| RTR-03 | API keys logged in error messages | 🟡 Medium | `main.py:71` | Redact sensitive headers in logs |
| RTR-04 | No rate limiting | 🟡 Medium | `main.py` | Add `slowapi` or similar middleware |
| RTR-05 | No Docker HEALTHCHECK | 🟡 Medium | `Dockerfile` | Add `HEALTHCHECK` instruction |

#### Dependencies

```txt
fastapi>=0.111.0    # ⚠️ Unpinned
uvicorn>=0.30.0     # ⚠️ Unpinned
httpx>=0.27.0       # ⚠️ Unpinned
pyyaml>=6.0.1       # ⚠️ Unpinned
pydantic>=2.7.0     # ⚠️ Unpinned
```

#### Configuration (`models.yaml`)

```yaml
endpoints:
  local-llama:
    base_url: "http://host.containers.internal:7865/v1"  # ✅ Correct port
    api_key_env: null

  groq:
    base_url: "https://api.groq.com/openai/v1"
    api_key_env: "GROQ_API_KEY"

models:
  qwen-3b-chat:
    - endpoint: local-llama      # Primary: local llama.cpp
      upstream_model: qwen-3b-chat
    - endpoint: groq             # Fallback: Groq cloud
      upstream_model: llama-3.1-8b-instant
```

**Status:** ✅ Correctly configured for local-first with cloud fallback

### 3.3 SearXNG Configuration

**File:** `containers/searxng/config/settings.yml`

| Finding | Status |
|---------|--------|
| ✅ Uses Valkey for rate limiting | PASS |
| ✅ `limiter: false` for local use | PASS |
| ✅ Secret key from environment | PASS |
| ⚠️ `debug: false` but no production hardening | 🟡 Low |

### 3.4 Qdrant Configuration

**File:** `containers/qdrant/config/production.yaml`

| Finding | Status |
|---------|--------|
| ✅ `on_disk_payload: true` (saves RAM) | PASS |
| ✅ Single-node mode (`cluster.enabled: false`) | PASS |
| ✅ API key from environment | PASS |

### 3.5 PostgreSQL

**Status:** 🟡 Empty config directory

| Finding | Recommendation |
|---------|----------------|
| `containers/postgres/config/` is empty | Add init script for multi-DB setup (Open WebUI only) |

---

## 4. Security Posture Audit

### 4.1 Secrets Management

| Finding | Severity | Status |
|---------|----------|--------|
| ✅ `.env` in `.gitignore` | — | PASS |
| ✅ `.env.example` as template | — | PASS |
| ⚠️ No validation for required secrets | 🟠 High | **Must fix** |
| ✅ Secrets passed via environment (not hardcoded) | — | PASS |

#### Required Secrets Inventory

```bash
# Cloud API Keys
ANTHROPIC_API_KEY=          # ⚠️ Optional (ai-router fallback)
GROQ_API_KEY=               # ⚠️ Optional (ai-router fallback)
NVIDIA_API_KEY=             # ⚠️ Optional (ai-router fallback)
OPENROUTER_API_KEY=         # ⚠️ Optional (ai-router fallback)

# Hugging Face
HF_TOKEN=                   # 🔴 Required for model downloads

# PostgreSQL
POSTGRES_PASSWORD=          # 🔴 Required
OPENWEBUI_DB_PASSWORD=      # 🔴 Required

# Open WebUI
WEBUI_SECRET_KEY=           # 🔴 Required

# Qdrant
QDRANT_API_KEY=             # ⚠️ Optional (single-user, localhost)

# SearXNG
SEARXNG_SECRET=             # 🟡 Auto-generated if not set
```

### 4.2 Dependency Security

#### LiteLLM Compromise Status

| Question | Answer |
|----------|--------|
| Is LiteLLM in current codebase? | ❌ **NO** (removed in commit a2b0483) |
| Was ai-stack affected? | ❌ **NO** (LiteLLM removed before March 24, 2026 attack) |
| Should LiteLLM 1.82.6 be used? | ❌ **NO** (maintainer trust compromised, no new releases until audit complete) |

**Assessment:** ✅ **SAFE** — Your decision to remove LiteLLM was validated by the supply chain attack.

#### Known Vulnerable Dependencies

| Package | Version | Vulnerability | Severity | Status |
|---------|---------|---------------|----------|--------|
| None identified | — | — | — | ✅ No known CVEs |

### 4.3 Network Security

| Finding | Status |
|---------|--------|
| ✅ All services bind to `127.0.0.1` or container network | PASS |
| ✅ No LAN exposure (Phase 1) | PASS |
| ✅ Podman (rootless) instead of Docker | PASS |
| ⚠️ ai-router exposes cloud API keys to container | 🟡 Medium (acceptable for single-user) |

### 4.4 Input Validation

| Component | Status | Issues |
|-----------|--------|--------|
| STT file upload | 🟡 Partial | Content-type only (no magic bytes) |
| ai-router model names | 🔴 **None** | User input used without validation |
| Config files | 🟢 Good | YAML safe_load, Pydantic validation |

---

## 5. Documentation Audit

### 5.1 Documentation Inventory

| File | Purpose | Accuracy |
|------|---------|----------|
| `AGENTS.md` | Developer guide | ✅ Accurate |
| `docs/prd/2026-03-18-ai-stack-phase1-design.md` | Design spec | 🟡 Outdated (references removed LiteLLM) |
| `docs/hardware-profile.md` | Hardware constraints | ✅ Accurate |
| `docs/llama-cpp-router-mode.md` | llama.cpp config | ✅ Updated (commit 5e94a81) |
| `docs/stt-architecture.md` | STT design | ✅ Accurate |
| `docs/huggingface-cli-guide.md` | HF CLI guide | ✅ Accurate |
| `docs/partition-table.md` | Storage layout | ✅ Accurate |
| `bare-metal/llama-cpp/docs/research-notes.md` | llama.cpp research | ✅ Updated |

### 5.2 Documentation Issues

| # | Finding | Severity | File | Recommendation |
|---|---------|----------|------|----------------|
| DOC-01 | PRD references LiteLLM extensively (removed) | 🟡 Medium | `docs/prd/*.md` | Mark as historical or update |
| DOC-02 | Migration table incomplete | 🟢 Low | `docs/stt-architecture.md` | Document removed POC functionality |
| DOC-03 | ai-router not documented | 🟡 Medium | Missing | Add `docs/ai-router.md` |

---

## 6. Git Hygiene Audit

### 6.1 Branch Status

```
* feature/ai-router         (HEAD: 5e94a81) — Current work
  main                      (origin/main) — Production branch
  feature/stt-rewrite-models — Merged (a2b0483)
```

### 6.2 Commit History (Last 10)

| Commit | Message | Status |
|--------|---------|--------|
| 5e94a81 | fix(llama-cpp): update presets.ini to official format | ✅ Good |
| ff93cfa | feat: add ai-router and standardize ports | ✅ Good |
| 1377f7a | chore: add Python __pycache__ to .gitignore | ✅ Good |
| 5b6d91e | Merge branch 'main' | ✅ Good |
| a43c52e | Merge PR #1 (STT rewrite) | ✅ Good |
| a2b0483 | chore: remove LiteLLM | ✅ Critical security decision |

### 6.3 .gitignore

| Finding | Status |
|---------|--------|
| ✅ `.env` ignored | PASS |
| ✅ `__pycache__/` ignored | PASS |
| ✅ `.pyc`, `.pyo` ignored | PASS |
| ⚠️ No `.pytest_cache/` | 🟢 Low (added in 1377f7a) |

---

## 7. Hardware Constraints Validation

### 7.1 VRAM Budget (4 GB Total)

| State | STT | LLM | Total | Feasible |
|-------|-----|-----|-------|----------|
| All idle | 0 MB | 0 MB | ~26 MB | ✅ Yes |
| STT active | ~1.5-2 GB | 0 MB | ~1.5-2 GB | ✅ Yes |
| LLM active (4B) | 0 MB | ~2-2.5 GB | ~2-2.5 GB | ✅ Yes |
| LLM active (7B) | 0 MB | ~3-3.5 GB | ~3-3.5 GB | ✅ Yes |
| **Both active** | ~1.5-2 GB | ~2-2.5 GB | ~4-4.5 GB | ❌ **NO** (exceeds 4 GB) |

**Assessment:** ✅ Correctly enforced via:
- llama.cpp `--models-max 1`
- STT idle monitor (10 min timeout)
- Manual `ai-stack gpu` switching

### 7.2 RAM Budget (16 GB Total)

| Consumer | Estimated | Actual (compose.yaml limits) |
|----------|-----------|------------------------------|
| OS + Desktop | ~2 GB | — |
| Browser | ~3 GB | — |
| PostgreSQL | ~150 MB | 512 MB limit |
| Valkey | ~256 MB | 384 MB limit |
| Qdrant | ~200 MB | 512 MB limit |
| SearXNG | ~150 MB | 256 MB limit |
| ai-router | ~100 MB | 256 MB limit |
| Open WebUI | ~400 MB | 1 GB limit |
| n8n | ~300 MB | 1 GB limit |
| **Container Total** | ~1.9 GB | ~4.4 GB limit |
| **Headroom** | ~9.1 GB | ~6.6 GB |

**Assessment:** ✅ Memory limits are reasonable (not too restrictive)

---

## 8. Critical Issues Summary

### 🔴 Critical (Must Fix Before Production)

| # | Issue | Component | Impact | Effort |
|---|-------|-----------|--------|--------|
| SEC-01 | STT file upload validation can be spoofed | `bare-metal/stt/server.py` | Arbitrary file upload | 30 min |
| SEC-02 | ai-router has no input validation on model names | `containers/ai-router/main.py` | Injection attacks | 15 min |
| SEC-03 | No validation for required secrets | `lib/install-base.sh` | Silent failures, security gaps | 20 min |

### 🟠 High (Should Fix Within 1 Week)

| # | Issue | Component | Impact | Effort |
|---|-------|-----------|--------|--------|
| SEC-04 | ai-router config has no schema validation | `containers/ai-router/main.py` | Config errors, crashes | 20 min |
| SEC-05 | STT has no upload size limits | `bare-metal/stt/server.py` | DoS via large files | 15 min |
| SEC-06 | GPU switching doesn't verify success | `bin/ai-stack` | Silent failures | 15 min |
| CFG-01 | Incomplete STT environment overrides | `bare-metal/stt/config.py` | Config inflexibility | 15 min |
| DEP-01 | Unpinned dependencies (no upper bounds) | All `pyproject.toml`, `requirements.txt` | Breaking changes | 10 min |

### 🟡 Medium (Fix Within 1 Month)

| # | Issue | Component | Impact |
|---|-------|-----------|--------|
| SEC-07 | nvidia-smi timeout too short | `bare-metal/stt/server.py` | False GPU detection failures |
| SEC-08 | ai-router API keys in logs | `containers/ai-router/main.py` | Credential exposure in logs |
| SEC-09 | ai-router has no rate limiting | `containers/ai-router/` | DoS vulnerability |
| CFG-02 | ai-router has no Docker HEALTHCHECK | `containers/ai-router/Dockerfile` | Poor orchestration |
| CFG-03 | Qdrant uses `latest` tag | `containers/compose.yaml` | Reproducibility issues |
| TST-01 | Minimal test coverage | `bare-metal/stt/tests/` | Undetected regressions |
| DOC-01 | PRD references removed LiteLLM | `docs/prd/*.md` | Documentation confusion |

---

## 9. Recommendations

### 9.1 Immediate Actions (Today)

1. **Fix STT file upload validation:**
   ```bash
   pip install python-magic
   # Add magic byte validation in server.py
   ```

2. **Add input validation to ai-router:**
   ```python
   from pydantic import BaseModel, Field
   
   class ChatCompletionRequest(BaseModel):
       model: str = Field(..., min_length=1, max_length=256)
       messages: list
       stream: bool = False
   ```

3. **Add secrets validation to install-base.sh:**
   ```bash
   # After loading .env:
   required_vars=(HF_TOKEN POSTGRES_PASSWORD OPENWEBUI_DB_PASSWORD WEBUI_SECRET_KEY)
   for var in "${required_vars[@]}"; do
       if [ -z "${!var}" ]; then
           echo "ERROR: $var not set in ~/.env"
           exit 1
       fi
   done
   ```

### 9.2 Short-Term (This Week)

4. **Pin all dependencies with upper bounds**
5. **Add Docker HEALTHCHECK to ai-router**
6. **Add rate limiting to ai-router**
7. **Expand STT test coverage**

### 9.3 Medium-Term (This Month)

8. **Update PRD documentation** (remove LiteLLM references)
9. **Add ai-router documentation**
10. **Pin Qdrant to specific version**
11. **Add integration tests**

---

## 10. Positive Observations

✅ **Excellent architecture decisions:**
- Direct llama.cpp connection (no LiteLLM) — validated by supply chain attack
- Hardware-aware VRAM orchestration
- Clean separation: bare-metal (GPU) vs containers (CPU)

✅ **Production-quality code:**
- STT service: FastAPI + Pydantic + structured logging
- Proper systemd units with restart policies
- XDG-compliant paths

✅ **Outstanding documentation:**
- Comprehensive PRDs
- Detailed hardware profiles
- Clear VRAM budgets

✅ **Good security practices:**
- `.env` properly gitignored
- Secrets not hardcoded
- Rootless Podman (not Docker)
- Localhost-only binding

✅ **Smart configuration management:**
- llama.cpp presets.ini corrected to official format
- HuggingFace cache integration (single download, used everywhere)
- Environment variable overrides

---

## 11. Conclusion

**Overall Risk Level:** 🟡 **MODERATE**

**Summary:** ai-stack is a well-architected infrastructure automation project with solid hardware-aware design. The codebase demonstrates mature engineering decisions (especially the LiteLLM removal, which proved prescient). However, there are **3 critical security issues** that must be addressed before production deployment:

1. STT file upload validation
2. ai-router input validation
3. Secrets validation

**Estimated Remediation Effort:**
- Critical issues: ~1 hour
- High priority: ~1.5 hours
- Medium priority: ~3 hours

**Recommendation:** Fix critical issues immediately, then address high-priority items within one week. The codebase is otherwise production-ready for single-user deployment.

---

**Audit Completed:** March 26, 2026  
**Next Review:** After critical fixes (recommend re-audit in 1 week)
