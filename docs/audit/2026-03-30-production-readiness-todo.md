# AI Stack Production Readiness TODO

**Date:** 2026-03-30  
**Branch:** `audit-2026-03-30`  
**Goal:** close the gap between intended architecture and shipped behavior so the stack is installable, operable, and internally consistent on a 4 GB VRAM workstation.

## Priority 0: Fix the broken runtime assumptions

### 1. Make Open WebUI STT work from a cold state

**Problem**
- `stt_proxy.py` unloads llama.cpp and waits for Whisper health, but it does not start `whisper-server` if the service is stopped.
- Current behavior forces one of two bad states:
  - keep Whisper running all the time and hold VRAM
  - let Open WebUI microphone requests fail after Whisper has been stopped

**Tasks**
- Decide the supported production behavior:
  - Option A: STT Proxy starts `whisper-server` on demand, waits for readiness, then forwards the request
  - Option B: Whisper must stay running whenever Open WebUI STT is enabled, and docs must state that explicitly
- If Option A:
  - update `bare-metal/stt-proxy/stt_proxy.py` to start `whisper-server.service` when Whisper is not running
  - wait on `/ready` instead of only `/health` if model readiness is required
  - handle timeout and systemd failure paths cleanly
- Align `bare-metal/stt/config/config.yaml` and docs with the chosen behavior

**Acceptance criteria**
- Clicking the Open WebUI microphone works when both `llama-cpp` and `whisper-server` are initially stopped
- No manual pre-start step is required unless explicitly documented as a supported constraint

### 2. Fix VRAM state synchronization

**Problem**
- `stt_proxy.py` writes a monotonic event-loop timestamp
- `bin/ai-stack` reads the same field as Unix epoch time
- `ai-stack vram llm` therefore makes decisions on corrupted elapsed-time math

**Tasks**
- Replace monotonic timestamp usage with Unix epoch seconds everywhere the shared state file is persisted
- Standardize the state-file schema in one place
- Add validation/fallback for malformed state files in `bin/ai-stack`
- If history is intended, implement it or remove the `history` command

**Acceptance criteria**
- `ai-stack vram stt`, STT Proxy, and `ai-stack vram llm` all read/write the same schema correctly
- `ai-stack vram status` reports sane elapsed times

## Priority 1: Fix install and operator workflow

### 3. Repair installation UX

**Problem**
- `install.sh` tells users to run `ai-stack install all`
- the installed CLI explicitly rejects `ai-stack install`

**Tasks**
- Choose one supported model:
  - Option A: implement `ai-stack install base|llama-cpp|stt|stt-proxy|all`
  - Option B: keep install scripts repo-only and fix all docs/messages accordingly
- Update:
  - `install.sh`
  - `lib/install-base.sh`
  - `README.md`
  - `AGENTS.md`
  - `IMPLEMENTATION_SUMMARY.md`
- Remove references to `.env.example` if the real source of truth is `~/.zshenv`

**Acceptance criteria**
- A first-time user can follow one documented install path without hitting a dead command

### 4. Make shipped features match documented features

**Problem**
- docs reference `bin/llama-router` but it does not exist
- docs present `hypr-stt` as a normal feature, but it only exists under `bare-metal/stt/poc/`

**Tasks**
- For `llama-router`, choose one:
  - implement the CLI
  - remove all references and point users to `curl` or `ai-stack`
- For Hyprland STT, choose one:
  - promote `poc/bin/hypr-stt` into supported installable code
  - or downgrade all references so it is clearly marked as experimental / not installed by default
- Update all affected docs

**Acceptance criteria**
- Every command shown in the main README exists after following the supported install path

## Priority 2: Tighten service behavior and operations

### 5. Clean up STT service lifecycle

**Problem**
- Whisper startup semantics are inconsistent across code and docs
- `load_on_startup` defaults to `true` in config, but several docs describe lazy loading
- `ExecStartPost` uses a fixed 15 second sleep to start the idle monitor

**Tasks**
- Decide whether Whisper is eager-load or lazy-load in production
- Make `config.py`, `config.yaml`, docs, and behavior agree
- Replace `ExecStartPost=/bin/sh -c 'sleep 15 ...'` with a readiness-aware mechanism
- Confirm idle monitor semantics for both eager and lazy load modes

**Acceptance criteria**
- Startup, readiness, and idle-unload behavior are deterministic and documented

### 6. Harden model unload behavior

**Problem**
- `TranscriptionService.unload_model()` only deletes the object reference
- actual VRAM release may depend on garbage collection and backend cleanup timing

**Tasks**
- Verify actual VRAM release behavior with `faster-whisper` on this machine
- If needed, add explicit cleanup steps and document backend expectations
- Add a regression check or operator command that confirms VRAM is released after stop

**Acceptance criteria**
- stopping Whisper consistently frees the expected VRAM range on the target hardware

### 7. Standardize JSON handling in shell scripts

**Problem**
- `whisper-client` parses JSON with `grep` and `cut`

**Tasks**
- Replace manual parsing with `jq`
- fail gracefully if `jq` is missing
- consider listing `jq` as an explicit dependency if required operationally

**Acceptance criteria**
- status output remains correct if response field ordering changes

### 8. Fix compose-level correctness issues

**Problem**
- `read_write: true` is non-standard in `containers/compose.yaml`
- `n8n` has no startup dependency declarations

**Tasks**
- replace invalid compose keys with supported ones
- review `depends_on` for all services
- validate the compose file with Podman Compose on the target environment

**Acceptance criteria**
- compose file validates cleanly and mounts behave as intended

## Priority 3: Testing and release discipline

### 9. Add production-facing verification scripts

**Tasks**
- Add a smoke-test script that verifies:
  - Open WebUI reachable
  - Whisper `/health` and `/ready`
  - llama.cpp `/health` and `/models`
  - STT Proxy `/health`
  - cold-start STT via proxy
  - unload/reload flow between STT and llama.cpp
- update `bare-metal/stt-proxy/test-router-mode.sh` to match the supported workflow

**Acceptance criteria**
- one command can verify the stack after install or after upgrades

### 10. Make tests runnable in a clean dev environment

**Tasks**
- document the test dependencies
- add a simple test runner path for STT unit tests
- ensure `pytest` is installed in the relevant venv or provide a `make`/script wrapper

**Acceptance criteria**
- a contributor can run unit tests and smoke tests without guessing environment setup

### 11. Do a full documentation reconciliation pass

**Tasks**
- reconcile these files against actual code:
  - `README.md`
  - `AGENTS.md`
  - `IMPLEMENTATION_SUMMARY.md`
  - `docs/stt-architecture.md`
  - `bare-metal/stt/docs/STT-WORKFLOWS.md`
- remove stale references to superseded services and commands
- explicitly mark POC-only artifacts

**Acceptance criteria**
- documentation describes the current repository, not prior intent

## Release checklist

- [ ] Fresh install path completes without dead commands
- [ ] Open WebUI chat works against llama.cpp on port `7865`
- [ ] Open WebUI microphone works from a cold state
- [ ] Hyprland STT path is either supported and installable, or clearly marked unsupported
- [ ] `ai-stack gpu stt` and `ai-stack gpu llm` behave predictably
- [ ] VRAM state file is correct and human-readable
- [ ] Smoke tests pass
- [ ] Main docs and install output match reality
