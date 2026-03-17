# ai-stack Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking. Every task MUST end with a git commit.

**Goal:** Setup an AI stack on Arch Linux featuring bare-metal GPU management (STT/llama.cpp) and containerized routing/frontend services (LiteLLM, Open WebUI, SearXNG, etc.), optimized for a constrained 4GB VRAM environment with a global OS-level environment setup.

**Architecture:** CLI wrapper (`ai-stack`) manages underlying `systemctl --user` units for mutually exclusive GPU services, and `podman compose` for CPU-bound infrastructure. Global config stored in `~/.env` and sourced in `~/.zshrc`.

**Tech Stack:** Bash, ZSH, Arch Linux (pacman), Podman, NVIDIA Container Toolkit, CUDA, Python, Docker Compose.

---

## Chunk 0: Documentation & Plan Persistence

**Files:**
- Create: `AGENTS.md`
- Create: `docs/superpowers/plans/2026-03-18-ai-stack-phase1.md`

### Task 1: Write Agent Instructions and Save Plan

- [x] **Step 1: Write `AGENTS.md`**
- [x] **Step 2: Save this entire plan to `docs/superpowers/plans/2026-03-18-ai-stack-phase1.md`**
- [ ] **Step 3: Commit Documentation**

```bash
git add AGENTS.md docs/superpowers/plans/2026-03-18-ai-stack-phase1.md
git commit -m "docs: finalize phase 1 implementation plan and agent rules"
```

---

## Chunk 1: System Bootstrap & Environment Configuration

**Files:**
- Create: `.env.example`
- Create: `lib/install-base.sh`

### Task 2: Create Global Environment Template

- [ ] **Step 1: Write `.env.example` file**
- [ ] **Step 2: Commit `.env.example`**

```bash
git add .env.example
git commit -m "chore: add global environment template"
```

### Task 3: Create System Bootstrap Script

- [ ] **Step 1: Write `lib/install-base.sh`**
- [ ] **Step 2: Make executable**
- [ ] **Step 3: Commit `install-base.sh`**

```bash
git add lib/install-base.sh
git commit -m "build: create system bootstrap script for arch linux"
```

---

## Chunk 2: Bare-metal Services (llama.cpp and STT)

**Files:**
- Create: `bare-metal/llama-cpp/install.sh`
- Create: `bare-metal/llama-cpp/config/presets.ini`
- Create: `bare-metal/llama-cpp/config/llama-cpp.service`
- Create: `bare-metal/stt/install.sh`
- Create: `bare-metal/stt/config/whisper-api.service`
- Create: `bare-metal/stt/config/whisper-idle-monitor.service`

### Task 4: Setup llama.cpp (Bare Metal)

- [ ] **Step 1: Write `bare-metal/llama-cpp/install.sh`**
- [ ] **Step 2: Write configs and systemd units**
- [ ] **Step 3: Commit llama.cpp setup**

```bash
git add bare-metal/llama-cpp/
git commit -m "feat(gpu): add llama.cpp bare-metal installation and service"
```

### Task 5: Setup Whisper STT (Bare Metal)

- [ ] **Step 1: Write `bare-metal/stt/install.sh`**
- [ ] **Step 2: Write STT systemd units**
- [ ] **Step 3: Commit STT setup**

```bash
git add bare-metal/stt/
git commit -m "feat(gpu): add whisper stt installation and systemd units"
```

---

## Chunk 3: Container Services (Podman Compose)

**Files:**
- Create: `containers/compose.yaml`
- Create: `containers/*/config/*`

### Task 6: Write Podman Compose File

- [ ] **Step 1: Write `containers/compose.yaml`**
- [ ] **Step 2: Commit compose file**

```bash
git add containers/compose.yaml
git commit -m "feat(containers): create podman compose orchestration"
```

### Task 7: Container Config Files

- [ ] **Step 1: Write config files for LiteLLM, Qdrant, SearXNG**
- [ ] **Step 2: Commit container configs**

```bash
git add containers/*/config/
git commit -m "chore(containers): add service configuration files"
```

---

## Chunk 4: CLI Wrapper and Keybindings

**Files:**
- Create: `bin/ai-stack`

### Task 8: Write `ai-stack` CLI

- [ ] **Step 1: Write `bin/ai-stack`**
- [ ] **Step 2: Make executable**
- [ ] **Step 3: Commit CLI wrapper**

```bash
git add bin/ai-stack
git commit -m "feat(cli): create ai-stack management utility"
```
