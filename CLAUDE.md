# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A starter template for running Claude Code inside a [Lima](https://lima-vm.io/) VM. The repo itself is the project that gets mounted into the VM at `/workspaces/$LIMA_INSTANCE`, so the same checkout is visible from both host and guest. Downstream projects are expected to copy/fork this skeleton and add their own code on top.

## Host vs. guest

Scripts are split between two execution contexts and refuse to run in the wrong one:

- **Host scripts** (`lima/*.sh` except `provision.sh`) source `lima/load-host-env.sh`, which errors out if `/run/lima-guestagent` exists (i.e. if accidentally run inside the VM).
- **Guest script** (`lima/provision.sh`) inverts the check — it errors out if `/run/lima-guestagent` does *not* exist.

When editing or adding scripts, preserve this guardrail.

## Common commands (run from host)

```bash
./lima/start.sh     # create + provision the VM (idempotent via SENTINEL_ID)
./lima/delete.sh    # force-delete the VM
./lima/rebuild.sh   # delete + start
./lima/ssh-bash.sh  # interactive bash inside the VM
./lima/ssh-claude.sh # launch `claude` inside the VM
./lima/ssh-code.sh  # open the workspace in VS Code via Remote-SSH
```

To set the default Lima instance for `limactl` in the current shell:

```bash
source ./lima/load-host-env.sh
```

## Configuration flow

1. `.env.example` is copied to `.env` automatically by `load-host-env.sh` on first run; the user must set `LIMA_INSTANCE` before scripts will proceed.
2. `load-host-env.sh` resolves `PROJECT_DIR` from `${BASH_SOURCE[0]:-${(%):-%x}}` so it works when sourced from both bash and zsh — do not regress this to plain `${BASH_SOURCE[0]}`.
3. `start.sh` passes `PROJECT_DIR` into the VM by overriding `.mounts[0].location` at the CLI rather than templating the YAML.

## Provisioning sentinel

`start.sh` generates a fresh `SENTINEL_ID` (timestamp + random) per invocation and passes it via `.param.sentinelId`. `provision.sh` writes it to `lima/var/.provisioned` only on success. After `limactl start` returns, the host script reads that file back and aborts if the value doesn't match — this is how a silently-failed provision is detected. Don't remove the sentinel check when modifying provisioning.

## Persistent guest state

`lima/var/` is host-mounted and gitignored (except its own `.gitignore`). It's used to keep guest state across VM rebuilds:

- `lima/var/home/.claude/` and `lima/var/home/.claude.json` are symlinked into the guest's `~/` during provisioning, so Claude Code config/credentials survive `rebuild.sh`.

If you add new persistent guest state, follow the same pattern (store under `lima/var/`, symlink from `~`).

## VM specs

Defined in `lima/lima.yaml`: Ubuntu 24.04 (`template:_images/ubuntu-24.04`), `vmType: vz`, 2 CPUs, 2 GiB RAM, 10 GiB disk, vzNAT networking. containerd is disabled. Claude Code is installed via `curl … claude.ai/install.sh | bash` with up to 3 retries.
