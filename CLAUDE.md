# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A standalone toolkit for running Claude Code inside a [Lima](https://lima-vm.io/) VM. The `bin/` directory is designed to be checked out once and added to `$PATH`; downstream projects then bootstrap their own VM by creating a `.env` file in the project root and running `limac-start` from there.

Projects do not vendor this toolkit. The toolkit and the project being worked on are fully decoupled.

## Layout

- `bin/` — **public** scripts only. This directory is meant to be added to the user's `$PATH`, so anything here is treated as a user-facing entry point. Do not put helpers, libraries, configs, or anything else in `bin/` that you wouldn't want exposed as a top-level command.
- Repo root — everything else: `lima.yaml`, `.env.example`, `load-host-env.sh` (sourced by the `bin/` scripts via `../load-host-env.sh`), and `CLAUDE.md`. Internal helpers and shared logic belong here, not in `bin/`.

## Two directories that matter

- **`TOOLKIT_DIR`** — the repo root, where `lima.yaml` and `.env.example` live. Resolved as `$(dirname "$0")/..` from a script in `bin/`, NOT from `$PWD`.
- **`PROJECT_DIR`** — `$PWD` at invocation time. The `.env` is read from here and this directory is what gets mounted into the VM at `/workspaces/$LIMA_INSTANCE`.

These are deliberately separate. `PROJECT_DIR` is **always** `$PWD`, never derived from the script location — this is a fail-safe so that running e.g. `limac-rebuild` from a subdirectory of the project doesn't silently mount the wrong tree.

## Persistent guest state

Per-instance state (the guest's `~/.claude/` config and credentials) lives in:

```
${LIMA_CLAUDE_STATE_DIR:-$HOME/.local/share/lima-claude}/<LIMA_INSTANCE>/
```

It is mounted into the VM at `/var/lib/lima-claude-state` and `~/.claude` / `~/.claude.json` in the guest are symlinked into it during provisioning. Survives `limactl delete` and therefore `limac-rebuild`. Override the base directory with `LIMA_CLAUDE_STATE_DIR`.

The provisioning sentinel (`.provisioned`) lives in this state dir and stores the `SENTINEL_ID` from the most recent successful provision. `limac-start` writes a fresh `SENTINEL_ID` per invocation via `--set .param.sentinelId`, the inline provision script writes it on success, and `limac-start` reads it back to detect a silently-failed provision. Don't remove this check.

## Host vs. guest

Scripts are split between two execution contexts:

- **Host scripts** (`bin/limac-*`) source `../load-host-env.sh`, which errors if `/run/lima-guestagent` exists.
- **Guest provisioning** is inlined in `lima.yaml` under `provision:` and runs only inside the VM.

## Common commands (run from PROJECT_DIR)

```bash
limac-start     # create + provision the VM
limac-delete    # force-delete the VM (state dir is preserved)
limac-rebuild   # delete + start
limac-shell     # interactive shell inside the VM
limac-claude    # launch `claude` inside the VM
limac-code      # open the workspace in VS Code via Remote-SSH
```

These all read `./.env` and require `LIMA_INSTANCE` to be set. Missing `.env` or empty `LIMA_INSTANCE` is a hard error — there is no auto-copy from `.env.example`. To bootstrap a new project, copy `.env.example` from the toolkit to your project's `.env` and set `LIMA_INSTANCE`.

## VM specs

Defined in `lima.yaml`: Ubuntu 24.04 (`template:_images/ubuntu-24.04`), 2 CPUs, 2 GiB RAM, 10 GiB disk. containerd is disabled. Claude Code is installed via `curl … claude.ai/install.sh | bash` with up to 3 retries.

## Per-platform Lima config

`lima.yaml` is a shared base. The platform-specific files extend it via `base: [./lima.yaml]`:

- **`lima.macos.yaml`** — sets `vmType: vz` and `networks: [{ vzNAT: true }]`, so the VM gets its own host-reachable IP via Apple's vmnet framework.
- **`lima.linux.yaml`** — falls back to Lima's default user-mode networking. Per-VM host-reachable IPs are **not** supported on Linux today (`socket_vmnet` and friends are macOS-only — see [Lima discussion #2499](https://github.com/lima-vm/lima/discussions/2499)). The default mode also doesn't auto-bind any host ports, which preserves the "no implicit host port binding" guarantee.

`bin/limac-start` picks the right file via `uname -s`. Other host OSes are a hard error. When adding settings that should apply to both platforms, put them in `lima.yaml`; only put platform-specific overrides in the `lima.<platform>.yaml` files.

## When editing scripts

- Preserve the host/guest guardrails (`/run/lima-guestagent` checks).
- Never derive `PROJECT_DIR` from the script location — it must always be `$PWD`.
- Keep the bash/zsh-compatible `${BASH_SOURCE[0]:-${(%):-%x}}` idiom for resolving `TOOLKIT_DIR`; plain `${BASH_SOURCE[0]}` silently breaks when the script is sourced from zsh.
