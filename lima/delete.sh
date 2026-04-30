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
  --force
  --tty=false
)

case $VERBOSITY in
  0) LIMACTL_ARGS+=(--log-level=warn) ;;
  1) LIMACTL_ARGS+= ;;
esac

echo "Deleting lima instance \"$LIMA_INSTANCE\""

limactl delete "${LIMACTL_ARGS[@]}" $LIMA_INSTANCE
