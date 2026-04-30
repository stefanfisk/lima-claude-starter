# Uses ${BASH_SOURCE[0]} which is a bash-specific variable, so it won't work in plain sh or zsh when
# sourced. In zsh, ${BASH_SOURCE[0]} is undefined, so the PROJECT_DIR calculation would silently
# break.
#
# The fix is to use ${BASH_SOURCE[0]:-${(%):-%x}} — the zsh equivalent of BASH_SOURCE is ${(%):-%x}:
_SCRIPT="${BASH_SOURCE[0]:-${(%):-%x}}"
PROJECT_DIR="$(cd "$(dirname "$_SCRIPT")/.." && pwd)"
unset _SCRIPT

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"

  echo "Created .env from .env.example — please review it before continuing." >&2
  exit 1
fi

# Unset any inherited value, then load from .env
unset LIMA_INSTANCE
source "$PROJECT_DIR/.env"

if [[ -z "$LIMA_INSTANCE" ]]; then
  echo "error: LIMA_INSTANCE must be set in .env" >&2
  exit 1
fi
