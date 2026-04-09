# Contributing

## Prerequisites

| Tool | How to get it |
|---|---|
| [Docker](https://docs.docker.com/get-docker/) | System package |
| [mise](https://mise.jdx.dev/getting-started.html) | See link |
| netcat | `sudo apt-get install netcat-openbsd` (Linux) / included on macOS |

Once mise is installed, run this once to install all other dev tools (shellcheck, hadolint, bats, rcon-cli):

```sh
make install-deps
```

## Running the test suite

```sh
# Static analysis (shellcheck + hadolint) + BATS unit tests
make

# Integration tests — starts real Minecraft servers (~3–10 min first run)
make integration-test
```

CI runs all of the above on every push and pull request.

## Project layout

```
alerts/                     Docker image: tails server log → Discord webhook
world-reset/                Docker image: periodically resets a Minecraft world
shared-config/              whitelist.json + ops.json (gitignored — production data)
data/                       Persistent server data volumes (gitignored)
tests/
  test_world_reset.bats     Unit tests for world-reset/world-reset.sh
  integration/
    run.sh                  Brings up the test stack and runs integration tests
    test_servers.bats       BATS integration tests (RCON-based)
docker-compose.yml          Production stack
docker-compose.test.yml     Integration test stack (ephemeral, port-offset, no auth)
Makefile                    Developer shortcuts
.mise.toml                  Pinned tool versions
renovate.json               Automated dependency updates (Renovate bot)
```

## Making changes

- **Shell scripts** — shellcheck must pass. Run `make lint`.
- **Dockerfiles** — hadolint must pass. Run `make lint-docker`. Package versions must be pinned (e.g. `bash=5.3.3-r1`).
- **docker-compose.yml** — validate with `make validate`.
- **Integration tests** — if you change plugin lists or server behaviour, update `tests/integration/test_servers.bats` to match.

## Dependency updates

[Renovate](https://github.com/apps/renovate) opens automated PRs weekly for:
- Dockerfile base images and package versions
- Docker Compose image tags
- GitHub Actions versions
- mise tool versions (`.mise.toml`)

When a Renovate PR lands, re-pin any affected package versions in the Dockerfiles to match.

## Environment variables

`world-reset/world-reset.sh` uses environment variables with sensible defaults so it can be tested without a live server. See the comments at the top of the script.

The production stack is configured via a `.env` file (gitignored). Copy `.env.template` to `.env` and fill in values before running `docker compose up`.
