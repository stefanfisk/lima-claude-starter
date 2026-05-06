if [[ -d /run/lima-guestagent ]]; then
  echo "Error: this script must be run on the host, not inside the Lima VM." >&2
  exit 1
fi

# Toolkit dir — the repo root, where this script and lima.yaml live. Resolved from
# the script location, NOT from $PWD. Uses ${BASH_SOURCE[0]} which is bash-specific;
# in zsh ${BASH_SOURCE[0]} is undefined, so the fallback ${(%):-%x} (zsh's equivalent)
# is used.
_SCRIPT="${BASH_SOURCE[0]:-${(%):-%x}}"
TOOLKIT_DIR="$(cd "$(dirname "$_SCRIPT")" && pwd)"
unset _SCRIPT

# Project dir — the user's cwd at invocation time. .env is read from here, and this
# is what gets mounted into the VM. Decoupled from TOOLKIT_DIR so the toolkit can be
# checked out anywhere and added to $PATH.
PROJECT_DIR="$PWD"

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  echo "error: $PROJECT_DIR/.env not found" >&2
  echo "       copy $TOOLKIT_DIR/.env.example to $PROJECT_DIR/.env and set LIMA_INSTANCE" >&2
  exit 1
fi

# Unset any inherited value, then load from .env
unset LIMA_INSTANCE
source "$PROJECT_DIR/.env"

if [[ -z "${LIMA_INSTANCE:-}" ]]; then
  echo "error: LIMA_INSTANCE must be set in $PROJECT_DIR/.env" >&2
  exit 1
fi

# State dir — persistent guest state (~/.claude config, credentials) keyed by instance.
# Survives `limactl delete` and limac-rebuild. Override with LIMA_CLAUDE_STATE_DIR.
STATE_DIR="${LIMA_CLAUDE_STATE_DIR:-$HOME/.local/share/lima-claude}/$LIMA_INSTANCE"
