# homeschool-minecraft

Docker Compose stack running two Paper Minecraft servers (survival + creative) with Discord alerting, automated PvP world resets, and NFS-based backups.

## Services

| Service | Description |
|---|---|
| `minecraft-survival` | Paper survival server with grief protection, WorldGuard, CoreProtect, DiscordSRV, and more |
| `minecraft-creative` | Paper creative server with matching plugin set |
| `alerts-survival` / `alerts-creative` | Tails the server log and forwards new lines to a Discord webhook |
| `pvp-reset` | Resets the `pvp` world on the survival server every 5 minutes (skips reset if players are present) |

Backups are handled outside Docker by `backup.sh`, which rsyncs the `backups/` directory to an NFS share and is invoked via cron on the host.

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
| `SURVIVAL_VERSION` / `CREATIVE_VERSION` | Minecraft version for each server |
| `SURVIVAL_GAME_PORT` / `CREATIVE_GAME_PORT` | Host port exposed for game connections |
| `SURVIVAL_RCON_PORT` / `CREATIVE_RCON_PORT` | Host port exposed for RCON |
| `RCON_PASSWORD` | Shared RCON password |
| `ALERTS_WEBHOOK` | Discord webhook URL for log alerts |
| `ALERTS_FILE` | Absolute path to the log file to monitor |
| `BACKUP_INTERVAL` | Backup cadence (e.g. `24h`) — used by the commented-out `mc-backup` services |
| `PRUNE_BACKUPS_DAYS` | Days of backups to retain |
| `SURVIVAL_RCON_CMDS_ON_CONNECT` / `CREATIVE_RCON_CMDS_ON_CONNECT` | RCON commands to run on server startup |

### Start the stack

```sh
docker compose up -d
```

## Backups

`backup.sh` mounts an NFS share and rsyncs `backups/` to it. Variables (all overridable via environment):

| Variable | Default |
|---|---|
| `BACKUP_DIR` | `/home/ubuntu/docker/minecraft/backups` |
| `NFS_SERVER_ADDRESS` | `home` |
| `NFS_SHARE` | `/mnt/internal/2/nfs/backup/minecraft` |
| `MOUNT_DIR` | `/mnt/backup/minecraft` |

Add it to root's crontab:

```
0 3 * * * /home/ubuntu/docker/minecraft/backup.sh
```

The commented-out `backups-survival` / `backups-creative` services in `docker-compose.yml` offer an alternative in-Docker backup approach using `itzg/mc-backup`.

## Shared config

`shared-config/whitelist.json` and `shared-config/ops.json` are bind-mounted into both servers so operator lists stay in sync. These files are gitignored (production data).

## Development & testing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide, including how to install dev tools, run the test suite, and work with integration tests.

```sh
make install-deps   # install shellcheck, hadolint, bats, rcon-cli via mise
make                # lint + unit tests
make integration-test  # spin up real servers and run RCON-based tests (~3–10 min)
```
