#!/bin/bash

set -e

source "$(dirname "$0")/load-env.sh"

VERBOSITY=""
while getopts "v" opt; do
  case $opt in
    v) VERBOSITY="${VERBOSITY}-v " ;;
  esac
done

"$PROJECT_DIR/lima/delete.sh" $VERBOSITY
"$PROJECT_DIR/lima/start.sh" $VERBOSITY
