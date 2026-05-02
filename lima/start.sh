#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/load-host-env.sh"

SENTINEL_ID="$(date -u +"%Y-%m-%dT%H:%M:%SZ")-$(head -c20 /dev/random | base64)"
SENTINEL="$PROJECT_DIR/lima/var/.provisioned"

echo "Starting lima instance \"$LIMA_INSTANCE\""
echo ""

limactl start \
  --tty=false \
  --progress \
  --name "$LIMA_INSTANCE" \
  --set ".param.sentinelId = \"$SENTINEL_ID\"" \
  --set ".mounts[0].location = \"$PROJECT_DIR\"" \
  "$PROJECT_DIR/lima/lima.yaml"

if [[ "$(cat "$SENTINEL")" != "$SENTINEL_ID" ]]; then
  echo ""
  echo "Failed to provision the Lima instance."
  echo ""
  echo "Deleting instance..."
  echo ""
  exit 1;
fi

echo ""
echo "Run this to set the default Lima instance:"
echo ""
echo "source ./lima/load-host-env.sh"
echo ""
