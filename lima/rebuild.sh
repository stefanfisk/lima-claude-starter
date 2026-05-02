#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/load-host-env.sh"

"$PROJECT_DIR/lima/delete.sh"
"$PROJECT_DIR/lima/start.sh"
