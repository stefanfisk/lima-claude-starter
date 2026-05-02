#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/load-host-env.sh"

echo "Deleting lima instance \"$LIMA_INSTANCE\""

limactl delete \
  --force \
  --tty=false \
  $LIMA_INSTANCE
