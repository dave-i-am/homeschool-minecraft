# homeschool-minecraft

Docker Compose stack running two Paper Minecraft servers (survival + creative) with Discord alerting, automated PvP world resets, and NFS-based backups.

## Services

| Service | Description |
|---|---|
| `minecraft-survival` | Paper survival server with grief protection, WorldGuard, CoreProtect, DiscordSRV, and more |
| `minecraft-creative` | Paper creative server with matching plugin set |
| `alerts-survival` / `alerts-creative` | Tails the server log and forwards new lines to a Discord webhook |
| `pvp-reset` | Resets the `pvp` world on the survival server every 5 minutes (skips reset if players are present) |
| `backups-creative` | `itzg/mc-backup` sidecar — takes restic snapshots of the creative server and stores them on NFS |

## Quick start

### Prerequisites

- Docker with Compose
- An `.env` file (see below)

### Configuration

All server-specific values live in `.env` (gitignored). Copy the template and fill in your values:

```sh
cp .env.template .env
$EDITOR .env
```

| Variable | Purpose |
|---|---|
| `TZ` | Timezone for all containers (e.g. `Pacific/Auckland`) |
| `SURVIVAL_VERSION` / `CREATIVE_VERSION` | Minecraft version for each server |
| `SURVIVAL_GAME_PORT` / `CREATIVE_GAME_PORT` | Host port exposed for game connections |
| `SURVIVAL_RCON_PORT` / `CREATIVE_RCON_PORT` | Host port exposed for RCON |
| `RCON_PASSWORD` | Shared RCON password |
| `ALERTS_WEBHOOK` | Discord webhook URL for log alerts |
| `ALERTS_FILE` | Absolute path to the log file to monitor |
| `BACKUP_INTERVAL` | How often to take a backup (e.g. `48h`) |
| `NFS_SERVER_ADDRESS` | Hostname or IP of the NFS server |
| `NFS_SHARE` | NFS export path (mounted as a Docker volume into the backup containers) |
| `RESTIC_PASSWORD` | Encryption password for the restic repositories |
| `PRUNE_RESTIC_RETENTION` | Restic forget flags controlling how many snapshots to keep (e.g. `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`) |
| `SURVIVAL_RCON_CMDS_ON_CONNECT` / `CREATIVE_RCON_CMDS_ON_CONNECT` | RCON commands to run on server startup |

### Start the stack

```sh
docker compose up -d
```

## Backups

Backups run inside Docker via `itzg/mc-backup` sidecars using [restic](https://restic.net/). Each backup container:

1. Flushes the Minecraft server to disk via RCON
2. Takes an incremental restic snapshot of the world data
3. Prunes old snapshots according to `PRUNE_RESTIC_RETENTION`

Snapshots are stored on an NFS share, mounted into the containers as the Docker named volume `nfs-backups` (NFSv3).

### NFS setup

The NFS export must use `no_root_squash,insecure` (Docker uses unprivileged ports). The directory on the NFS server must be owned by root so the `itzg/mc-backup` entrypoint keeps root privileges when writing restic metadata.

```sh
# On the NFS server
sudo chown root:root /path/to/nfs/share
# /etc/exports entry:
/path/to/nfs/share  <client-cidr>(rw,no_subtree_check,no_root_squash,insecure)
sudo exportfs -ra
```

> **Note:** `backups-survival` is currently commented out in `docker-compose.yml` due to disk space constraints. Uncomment it once space is available — the restic repo at `/backups/survival` will be initialised automatically on first run.

## Shared config

`shared-config/whitelist.json` and `shared-config/ops.json` are bind-mounted into both servers so operator lists stay in sync. These files are gitignored (production data).

## Development & testing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide, including how to install dev tools, run the test suite, and work with integration tests.

```sh
make install-deps   # install shellcheck, hadolint, bats, rcon-cli via mise
make                # lint + unit tests
make integration-test  # spin up real servers and run RCON-based tests (~3–10 min)
```
