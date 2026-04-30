#!/bin/bash

set -e

source "$(dirname "$0")/load-env.sh"

VERBOSITY=0
while getopts "v" opt; do
  case $opt in
    v) ((VERBOSITY++)) ;;
    *) echo "usage: $0 [-v|-vv]" >&2; exit 1 ;;
  esac
done

LIMACTL_ARGS=(
  --tty=false
  --name="$LIMA_INSTANCE"
  --set=".mounts[0].location = \"$PROJECT_DIR\""
)

case $VERBOSITY in
  0) LIMACTL_ARGS+=(--log-level=warn) ;;
  1) LIMACTL_ARGS+= ;;
  *) LIMACTL_ARGS+=(--progress) ;;
esac

echo "Starting lima instance \"$LIMA_INSTANCE\""

limactl start "${LIMACTL_ARGS[@]}" "$PROJECT_DIR/lima/lima.yaml"

echo ""
echo "Run this to set the default Lima instance:"
echo ""
echo "source ./lima/load-env.sh"
echo ""
