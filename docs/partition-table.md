# Partition Table Specification

This document defines the finalized dual-NVMe storage architecture for the Arch Linux workstation.

## Philosophy: Disposable vs. Persistent
- **NVMe 0 (System Disk)**: OS, core runtimes, disposable cache. Can be wiped and reinstalled without data loss.
- **NVMe 1 (Data Disk)**: Permanent user data, development projects, and persistent service databases. Never touched on reinstall.

---

## Drive 1: `/dev/nvme0n1` (System)
**Focus**: Performance, snapshots, and temporary storage.
**Behavior**: Always formatted on install/reinstall. Repartitioned only if labels are missing.

| Partition | Mount Point | Size | Filesystem | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **p1** | `/boot` | 2 GiB | FAT32 | UEFI Bootloader (GRUB) |
| **p2** | `[swap]` | 32 GiB | Swap | Hibernation support (RAM <= 32GB) |
| **p3** | `/` | 140 GiB | Btrfs | Arch OS + System Packages + Snapper Snapshots |
| **p4** | `/downloads` | 726 GiB | Btrfs | ISOs, Media Cache, Temp Files |
| **-** | `Unallocated` | ~31 GiB | - | Btrfs headroom |

---

## Drive 2: `/dev/nvme1n1` (Data)
**Focus**: Persistent services and user workspace.
**Behavior**: Partitioned and formatted ONLY on first install. On reinstall, mounted as-is (data preserved).

| Partition | Mount Point | Size | Filesystem | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **p1** | `/home` | 80 GiB | Btrfs | Configs, dotfiles, mise runtimes |
| **p2** | `/workspace` | 300 GiB | Btrfs | Development Projects |
| **p3** | `/obsidian` | 80 GiB | Btrfs | Notes Vault & Knowledge Base |
| **p4** | `/srv` | 440 GiB | Btrfs | Podman Storage & Databases |
| **-** | `Unallocated` | ~31 GiB | - | Btrfs headroom |

---

## Mounting Details
All Btrfs partitions are mounted with the following optimized options:
- `compress=zstd:1`
- `relatime,space_cache=v2`

### Full Mount Hierarchy
| Mount Point | Partition | Drive | Filesystem |
| :--- | :--- | :--- | :--- |
| `/` | `p3` | NVMe 0 | Btrfs |
| `/boot` | `p1` | NVMe 0 | FAT32 |
| `/downloads`| `p4` | NVMe 0 | Btrfs |
| `/home` | `p1` | NVMe 1 | Btrfs |
| `/workspace`| `p2` | NVMe 1 | Btrfs |
| `/obsidian` | `p3` | NVMe 1 | Btrfs |
| `/srv` | `p4` | NVMe 1 | Btrfs |

---

## Snapshot & Rollback (Snapper + GRUB)

Snapshots are stored on the **root partition** (`/`, 140 GiB) using Snapper.

| Component | Purpose |
| :--- | :--- |
| `snapper` | Manages Btrfs snapshots on `/` |
| `snap-pac` | Pacman hook: auto-creates pre/post snapshots on every `pacman` transaction |
| `grub-btrfs-support` | `grub-btrfsd` daemon watches `/.snapshots` and updates GRUB entries |
| `snapper-cleanup.timer` | Auto-deletes snapshots older than 30 days |
| `snapper-timeline.timer` | Creates periodic timeline snapshots |

### Retention Policy
| Setting | Value | Effect |
| :--- | :--- | :--- |
| `NUMBER_LIMIT` | 20 | Max 20 pacman-triggered snapshots |
| `NUMBER_LIMIT_IMPORTANT` | 10 | Max 10 important snapshots |
| `TIMELINE_LIMIT_DAILY` | 30 | Keep 30 days of daily snapshots |
| `TIMELINE_LIMIT_HOURLY` | 0 | No hourly snapshots |
| `TIMELINE_LIMIT_WEEKLY` | 0 | No weekly snapshots |
| `TIMELINE_LIMIT_MONTHLY` | 0 | No monthly snapshots |

### Rollback Workflow
1. System crashes after `pacman -Syu`
2. Reboot
3. Select a snapshot from the GRUB menu ("Arch Linux Snapshots")
4. System boots into the pre-update state
5. Done

---

## Service Directory Structure (`/srv`)
The `/srv` partition handles all persistent data for rootless Podman services.

```text
/srv/
├── containers/               # Podman graphroot (images, layers)
├── ollama/
│   └── models/               # LLM model weights
├── databases/
│   ├── postgres/             # PostgreSQL data volumes
│   ├── mongo/                # MongoDB data volumes
│   ├── qdrant/               # Vector database storage
│   └── valkey/               # Caching layer data
├── n8n/
│   └── data/                 # Workflow & encryption data
└── openwebui/
    └── app/                  # Frontend user uploads & DB
```

---

## Reference `/etc/fstab`
Use this template for static filesystem identification. Use `UUID` or `PARTUUID` in the real file.

```fstab
# <file system> <mount point> <type> <options> <dump> <pass>

# NVMe 0 - System Disk
/dev/nvme0n1p1  /boot       vfat    defaults,noatime,nofail                   0 2
/dev/nvme0n1p2  none        swap    defaults,pri=-2                           0 0
/dev/nvme0n1p3  /           btrfs   rw,relatime,compress=zstd:1,space_cache=v2 0 0
/dev/nvme0n1p4  /downloads  btrfs   rw,relatime,compress=zstd:1,space_cache=v2 0 2

# NVMe 1 - Data Disk (persistent)
/dev/nvme1n1p1  /home       btrfs   rw,relatime,compress=zstd:1,space_cache=v2 0 2
/dev/nvme1n1p2  /workspace  btrfs   rw,relatime,compress=zstd:1,space_cache=v2 0 2
/dev/nvme1n1p3  /obsidian   btrfs   rw,relatime,compress=zstd:1,space_cache=v2 0 2
/dev/nvme1n1p4  /srv        btrfs   rw,relatime,compress=zstd:1,space_cache=v2 0 2

# RAM-based filesystems (tmpfs)
tmpfs           /tmp        tmpfs   defaults,noatime,mode=1777                0 0
tmpfs           /run        tmpfs   defaults,noatime,nosuid,nodev,mode=755     0 0
```

---

## Impact on Workflow
1. **Mise Runtimes**: Stored in `/home/.local/share/mise/` (NVMe 1), persistent across OS wipes.
2. **Services**: All container data (PostgreSQL, MongoDB, Ollama models) resides in `/srv/` (NVMe 1).
3. **OS Wipe**: You can format NVMe 0 (p3) at any time to get a fresh Arch install; remount NVMe 1 to restore your work environment.
4. **Rollback**: Select a Snapper snapshot from the GRUB menu to revert to a pre-update state.

---

## Partition Detection (Installer Behavior)

| Disk | Check | Label Exists | Label Missing |
| :--- | :--- | :--- | :--- |
| System (`nvme0n1`) | `blkid -L ARCH_ROOT` | Skip repartition, format always | Repartition + format |
| Data (`nvme1n1`) | `blkid -L ARCH_HOME` | Skip repartition, mount only | Repartition + format |
