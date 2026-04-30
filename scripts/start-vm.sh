#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"

  echo "Created .env from .env.example — please review it before continuing." >&2
  exit 1
fi

# Unset any inherited value, then load from .env
unset LIMA_INSTANCE
set -a
source "$PROJECT_DIR/.env"
set +a

if [[ -z "$LIMA_INSTANCE" ]]; then
  echo "error: LIMA_INSTANCE must be set in .env" >&2
  exit 1
fi

limactl start \
  --tty=false \
  --name="$LIMA_INSTANCE" \
  --set=".mounts[0].location = \"$PROJECT_DIR\"" \
  "$PROJECT_DIR/lima.yaml"
