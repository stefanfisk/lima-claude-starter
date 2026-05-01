#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/load-host-env.sh"

code --folder-uri "vscode-remote://ssh-remote+lima-${LIMA_INSTANCE}/workspaces/${LIMA_INSTANCE}"
