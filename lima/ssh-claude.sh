#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/load-host-env.sh"

exec ssh -t "lima-${LIMA_INSTANCE}" bash -i -c 'claude'
