#!/bin/bash

# Integration test suite for bin/limac-* scripts.
#
#   tests/run.sh             # full suite — creates a real VM (slow, ~3–5 min)
#   tests/run.sh --fast      # only the error-path tests, no VM created
#
# The suite uses a throwaway state dir under $TMPDIR (LIMA_CLAUDE_STATE_DIR
# override) so the user's real ~/.local/share/lima-claude is never touched.
# It also runs from a freshly-created project dir, exercising the cwd-based
# PROJECT_DIR resolution.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTANCE="limac-test-$(head -c 4 /dev/urandom | xxd -p)"
TMPDIR_TEST="$(mktemp -d)"
PROJECT_DIR="$TMPDIR_TEST/project"
export LIMA_CLAUDE_STATE_DIR="$TMPDIR_TEST/state"
STATE_DIR="$LIMA_CLAUDE_STATE_DIR/$INSTANCE"

FAST=0
[[ "${1:-}" == "--fast" ]] && FAST=1

mkdir -p "$PROJECT_DIR"

cleanup() {
  echo
  echo "=== cleanup ==="
  limactl delete --force "$INSTANCE" >/dev/null 2>&1 || true
  rm -rf "$TMPDIR_TEST"
}
trap cleanup EXIT

PASS=0
FAIL=0
CURRENT=""

test_case() {
  CURRENT="$1"
  echo
  echo "=== $CURRENT ==="
}

ok()   { echo "  ok  — $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL — $1" >&2; FAIL=$((FAIL+1)); }

# Each test runs from PROJECT_DIR, since limac-* scripts derive PROJECT_DIR=$PWD.
cd "$PROJECT_DIR"

# --- Error-path tests (fast) ---------------------------------------------------

test_case "limac-start fails when .env is missing"
rm -f "$PROJECT_DIR/.env"
if "$REPO_ROOT/bin/limac-start" >out.log 2>err.log; then
  fail "expected non-zero exit, got 0"
else
  grep -q "\.env" err.log && ok "stderr mentions .env" || fail "stderr did not mention .env (got: $(cat err.log))"
fi

test_case "limac-start fails when LIMA_INSTANCE is empty"
echo "LIMA_INSTANCE=" > "$PROJECT_DIR/.env"
if "$REPO_ROOT/bin/limac-start" >out.log 2>err.log; then
  fail "expected non-zero exit, got 0"
else
  grep -q "LIMA_INSTANCE" err.log && ok "stderr mentions LIMA_INSTANCE" || fail "stderr did not mention LIMA_INSTANCE (got: $(cat err.log))"
fi

if [[ $FAST -eq 1 ]]; then
  echo
  echo "=== fast suite complete ==="
  echo "Results: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
  exit
fi

# --- Integration tests (slow — real VM) ----------------------------------------

# Bind .env to the throwaway instance for the rest of the run.
echo "LIMA_INSTANCE=$INSTANCE" > "$PROJECT_DIR/.env"

test_case "limac-start creates VM and provisions state dir"
if "$REPO_ROOT/bin/limac-start"; then
  ok "limac-start exited 0"
else
  fail "limac-start exited non-zero"
  echo "Aborting integration tests — VM not created."
  echo
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

if limactl list -q | grep -qx "$INSTANCE"; then
  ok "limactl list shows $INSTANCE"
else
  fail "limactl list does not show $INSTANCE"
fi

if [[ -f "$STATE_DIR/.provisioned" ]]; then
  ok "$STATE_DIR/.provisioned exists"
else
  fail "$STATE_DIR/.provisioned missing"
fi

test_case "limac-shell can run a command in the VM"
out="$(echo 'echo hello-from-vm' | "$REPO_ROOT/bin/limac-shell" 2>err.log)" || true
if [[ "$out" == *"hello-from-vm"* ]]; then
  ok "got expected output via limac-shell"
else
  fail "expected 'hello-from-vm' in output, got: $out (stderr: $(cat err.log))"
fi

test_case "claude is installed in the VM"
out="$(echo 'claude --version' | "$REPO_ROOT/bin/limac-shell" 2>err.log)" || true
if [[ -n "$out" && "$out" != *"command not found"* ]]; then
  ok "claude --version returned: $(echo "$out" | head -1)"
else
  fail "claude --version failed (stdout: $out, stderr: $(cat err.log))"
fi

test_case "guest ~/.claude is symlinked into the state mount"
out="$(echo 'readlink ~/.claude' | "$REPO_ROOT/bin/limac-shell" 2>err.log)" || true
if [[ "$out" == "/var/lib/lima-claude-state/home/.claude" ]]; then
  ok "~/.claude → $out"
else
  fail "expected ~/.claude → /var/lib/lima-claude-state/home/.claude, got: $out"
fi

test_case "state survives limac-rebuild"
marker="state-marker-$(date +%s)"
echo "$marker" > "$STATE_DIR/home/.claude/test-marker"
if "$REPO_ROOT/bin/limac-rebuild"; then
  ok "limac-rebuild exited 0"
else
  fail "limac-rebuild exited non-zero"
fi
if [[ -f "$STATE_DIR/home/.claude/test-marker" ]] \
   && [[ "$(cat "$STATE_DIR/home/.claude/test-marker")" == "$marker" ]]; then
  ok "marker file survived rebuild"
else
  fail "marker file lost across rebuild"
fi

test_case "limac-delete removes the VM but preserves state"
if "$REPO_ROOT/bin/limac-delete"; then
  ok "limac-delete exited 0"
else
  fail "limac-delete exited non-zero"
fi
if limactl list -q | grep -qx "$INSTANCE"; then
  fail "instance still present after limac-delete"
else
  ok "instance removed"
fi
if [[ -f "$STATE_DIR/home/.claude/test-marker" ]]; then
  ok "state dir preserved across delete"
else
  fail "state dir wiped by delete"
fi

# limac-code is intentionally not exercised here — it launches the host's VS Code
# binary against the running VM via Remote-SSH, which opens a GUI window and isn't
# meaningful in a headless test environment.

# --- Summary -------------------------------------------------------------------

echo
echo "=== summary ==="
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
