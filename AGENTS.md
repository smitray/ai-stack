# AI Stack - Agent Instructions

When working in this repository, agents MUST adhere to the following rules:

1. **Hardware Constraints:** The target system is an Arch Linux machine with a strict 4GB VRAM limit. GPU services (STT, llama.cpp) are mutually exclusive and run bare-metal via `systemctl --user`.
2. **Environment Rule:** Secrets (API keys, HF_TOKEN) and paths are strictly stored in `~/.env` (user's home directory). The repository does NOT contain a `.env` file. `~/.env` is sourced by `~/.zshrc`.
3. **Container Engine:** Podman is strictly used. Docker is not installed. `podman compose` is the orchestrator.
4. **CUDA:** Arch Linux installs CUDA to `/opt/cuda`. Scripts must explicitly export `CUDA_HOME`, `PATH`, and `LD_LIBRARY_PATH` when compiling or running GPU workloads.
5. **Commits:** Every discrete task MUST be followed by a `git commit`.
