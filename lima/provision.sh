#!/bin/bash

set -eux -o pipefail

if [[ ! -d /run/lima-guestagent ]]; then
  echo "Error: this script must be run inside the Lima VM, not on the host." >&2
  exit 1
fi

PROJECT_DIR="${1:?}"
SENTINEL_ID="${2:?}"

PROJECT_VAR="$PROJECT_DIR/lima/var"
SENTINEL="$PROJECT_VAR/.provisioned"

echo ""
echo "Installing claude code"
echo ""

mkdir -p "$PROJECT_VAR/home/.claude"
ln -s "$PROJECT_VAR/home/.claude" ~/.claude
ln -s "$PROJECT_VAR/home/.claude.json" ~/.claude.json

echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
PATH="$HOME/.local/bin:$PATH"

# install.sh sometimes fails, retry up to 3 times
for i in 1 2 3; do
    curl -fsSL https://claude.ai/install.sh | bash && break
    echo "Claude install attempt $i failed, retrying..."
    sleep 5
done
if ! command -v claude &>/dev/null; then
    echo "ERROR: Claude CLI failed to install after retries"
    exit 1
fi

echo ""
echo "cd to $PROJECT_DIR on login"
echo ""

echo "cd \"$PROJECT_DIR\" 2>/dev/null || true" >> ~/.bashrc

echo "$SENTINEL_ID" > "$SENTINEL"
