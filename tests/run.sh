#!/usr/bin/env bash

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
CLI="$ROOT/agent-env"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/agent-env-tests.XXXXXX") || exit 1
TESTS=0
FAILURES=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

pass() {
  TESTS=$((TESTS + 1))
  printf 'PASS %s\n' "$1"
}

fail_test() {
  TESTS=$((TESTS + 1))
  FAILURES=$((FAILURES + 1))
  printf 'FAIL %s\n' "$1" >&2
}

assert_file() {
  [ -f "$1" ] || {
    printf '  missing file: %s\n' "$1" >&2
    return 1
  }
}

assert_contains() {
  file=$1
  expected=$2
  grep -F "$expected" "$file" >/dev/null 2>&1 || {
    printf '  %s does not contain: %s\n' "$file" "$expected" >&2
    return 1
  }
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf '  unexpected path exists: %s\n' "$1" >&2
    return 1
  }
}

make_contract() {
  file=$1
  modules=${2:-false}
  payload=${3:-No setup required}
  cat > "$file" <<EOF
AES_VERSION=1
PROJECT_NAME=Test Project
PURPOSE=Exercise the agent environment CLI
AUDIENCE=Test users
FIRST_MILESTONE=Generate a complete environment
TECH_CONSTRAINTS=Portable shell
SETUP_COMMAND=$payload
TEST_COMMAND=./tests.sh
LINT_COMMAND=bash -n script.sh
ALLOWED_ACTIONS=Read and edit task files
RESTRICTED_PATHS=Secrets and external files
SUCCESS_CRITERIA=All expected files exist and validation passes
MODULE_POLICY=$modules
MODULE_EVALS=$modules
MODULE_CLAUDE=$modules
EOF
}

test_blank_init() {
  target="$TMP_ROOT/project with spaces"
  contract="$TMP_ROOT/blank.conf"
  make_contract "$contract" true
  "$CLI" init "$target" --from "$contract" >/dev/null || return 1
  assert_file "$target/AGENTS.md" || return 1
  assert_file "$target/docs/PROJECT_BRIEF.md" || return 1
  assert_file "$target/.agent-env/HANDOFF.md" || return 1
  assert_file "$target/contracts/AGENT_POLICY.md" || return 1
  assert_file "$target/evals/acceptance.md" || return 1
  assert_file "$target/CLAUDE.md" || return 1
  assert_contains "$target/AGENTS.md" "### 1. Think Before Coding" || return 1
  assert_contains "$target/AGENTS.md" "### 4. Goal-Driven Execution" || return 1
  branch=$(git -C "$target" symbolic-ref --short HEAD) || return 1
  [ "$branch" = "main" ] || return 1
  if git -C "$target" rev-parse HEAD >/dev/null 2>&1; then
    printf '  init unexpectedly created a commit\n' >&2
    return 1
  fi
}

test_idempotent_render() {
  target="$TMP_ROOT/idempotent"
  contract="$TMP_ROOT/idempotent.conf"
  mkdir -p "$target"
  make_contract "$contract" false
  "$CLI" init "$target" --from "$contract" >/dev/null || return 1
  before=$(cksum "$target/AGENTS.md" "$target/docs/PROJECT_BRIEF.md")
  "$CLI" render "$target" >/dev/null || return 1
  after=$(cksum "$target/AGENTS.md" "$target/docs/PROJECT_BRIEF.md")
  [ "$before" = "$after" ]
}

test_adopt_preserves_content() {
  target="$TMP_ROOT/adopt"
  contract="$TMP_ROOT/adopt.conf"
  mkdir -p "$target"
  printf '# Human instructions\n\nKeep this text.\n' > "$target/AGENTS.md"
  printf 'custom.log\n' > "$target/.gitignore"
  make_contract "$contract" false
  if "$CLI" init "$target" --from "$contract" >/dev/null 2>&1; then
    printf '  init should reject unmarked files without --adopt\n' >&2
    return 1
  fi
  [ ! -d "$target/.git" ] || {
    printf '  failed preflight initialized Git\n' >&2
    return 1
  }
  [ ! -e "$target/.agent-env/environment.conf" ] || {
    printf '  failed preflight wrote the contract\n' >&2
    return 1
  }
  "$CLI" init "$target" --from "$contract" --adopt >/dev/null || return 1
  assert_contains "$target/AGENTS.md" "Keep this text." || return 1
  assert_contains "$target/AGENTS.md" "<!-- BEGIN AGENT-ENV: AGENTS -->" || return 1
  assert_contains "$target/.gitignore" "custom.log" || return 1
}

test_invalid_contracts() {
  target="$TMP_ROOT/invalid"
  mkdir -p "$target/.agent-env"
  make_contract "$target/.agent-env/environment.conf" false
  printf 'PROJECT_NAME=Duplicate\n' >> "$target/.agent-env/environment.conf"
  if "$CLI" validate "$target" >/dev/null 2>&1; then
    printf '  duplicate key was accepted\n' >&2
    return 1
  fi
  sed 's/PROJECT_NAME=Duplicate/UNSUPPORTED=value/' "$target/.agent-env/environment.conf" > "$target/.agent-env/unknown.conf"
  mv "$target/.agent-env/unknown.conf" "$target/.agent-env/environment.conf"
  if "$CLI" validate "$target" >/dev/null 2>&1; then
    printf '  unsupported key was accepted\n' >&2
    return 1
  fi
}

test_marker_conflict() {
  target="$TMP_ROOT/markers"
  contract="$TMP_ROOT/markers.conf"
  mkdir -p "$target"
  make_contract "$contract" false
  "$CLI" init "$target" --from "$contract" >/dev/null || return 1
  printf '\n<!-- BEGIN AGENT-ENV: AGENTS -->\n' >> "$target/AGENTS.md"
  if "$CLI" render "$target" >/dev/null 2>&1; then
    printf '  duplicate marker was accepted\n' >&2
    return 1
  fi
}

test_literal_values() {
  target="$TMP_ROOT/literal"
  contract="$TMP_ROOT/literal.conf"
  marker="$TMP_ROOT/should-not-exist"
  mkdir -p "$target"
  make_contract "$contract" false "\$(touch $marker); echo literal"
  "$CLI" init "$target" --from "$contract" >/dev/null || return 1
  assert_not_exists "$marker" || return 1
  assert_contains "$target/AGENTS.md" "\$(touch $marker); echo literal" || return 1
}

test_dry_run() {
  target="$TMP_ROOT/dry-run"
  contract="$TMP_ROOT/dry-run.conf"
  mkdir -p "$target"
  make_contract "$contract" false
  "$CLI" init "$target" --from "$contract" >/dev/null || return 1
  before=$(cksum "$target/AGENTS.md")
  sed 's/PROJECT_NAME=Test Project/PROJECT_NAME=Changed Project/' "$target/.agent-env/environment.conf" > "$target/.agent-env/changed.conf"
  mv "$target/.agent-env/changed.conf" "$target/.agent-env/environment.conf"
  "$CLI" render "$target" --dry-run >/dev/null || return 1
  after=$(cksum "$target/AGENTS.md")
  [ "$before" = "$after" ]
}

test_dry_run_new_project() {
  target="$TMP_ROOT/dry-new"
  contract="$TMP_ROOT/dry-new.conf"
  make_contract "$contract" true
  "$CLI" init "$target" --from "$contract" --dry-run >/dev/null || return 1
  assert_not_exists "$target"
}

test_doctor_detects_stale_content() {
  target="$TMP_ROOT/stale"
  contract="$TMP_ROOT/stale.conf"
  mkdir -p "$target"
  make_contract "$contract" false
  "$CLI" init "$target" --from "$contract" >/dev/null || return 1
  sed 's/PROJECT_NAME=Test Project/PROJECT_NAME=Changed Project/' "$target/.agent-env/environment.conf" > "$target/.agent-env/changed.conf"
  mv "$target/.agent-env/changed.conf" "$target/.agent-env/environment.conf"
  if "$CLI" doctor "$target" >/dev/null 2>&1; then
    printf '  doctor accepted stale generated content\n' >&2
    return 1
  fi
}

test_symlink_refusal() {
  target="$TMP_ROOT/symlink"
  outside="$TMP_ROOT/outside"
  contract="$TMP_ROOT/symlink.conf"
  mkdir -p "$target" "$outside"
  ln -s "$outside" "$target/docs"
  make_contract "$contract" false
  if "$CLI" init "$target" --from "$contract" >/dev/null 2>&1; then
    printf '  symlinked managed path was accepted\n' >&2
    return 1
  fi
  assert_not_exists "$outside/PROJECT_BRIEF.md"
}

run_test() {
  name=$1
  if "$name"; then
    pass "$name"
  else
    fail_test "$name"
  fi
}

run_test test_blank_init
run_test test_idempotent_render
run_test test_adopt_preserves_content
run_test test_invalid_contracts
run_test test_marker_conflict
run_test test_literal_values
run_test test_dry_run
run_test test_dry_run_new_project
run_test test_doctor_detects_stale_content
run_test test_symlink_refusal

printf '\n%s test(s), %s failure(s)\n' "$TESTS" "$FAILURES"
[ "$FAILURES" -eq 0 ]
