#!/usr/bin/env bash
# test_worktree_hygiene.sh — exercise rp-worktree-hygiene across isolation scenarios.
#
# Builds disposable git repositories under a temp directory and asserts the
# checker's exit code and report for: clean, dirty, missing upstream, merged
# branch, detached HEAD, multiple-worktree, prunable metadata, and two
# concurrent-session isolation simulations.

# --- Standalone bootstrap (when not sourced by tests/run.sh) ----------------
if [[ -z "${KIT_DIR:-}" ]]; then
  KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
if ! declare -F pass >/dev/null 2>&1; then
  PASSED=0; FAILED=0
  pass() { PASSED=$((PASSED+1)); echo "  PASS $1"; }
  fail() { FAILED=$((FAILED+1)); echo "  FAIL $1"; }
  warn() { echo "  WARN $1"; }
  finish() { echo ""; echo "Results: $PASSED passed, $FAILED failed"; [[ "$FAILED" -eq 0 ]]; }
fi

HYGIENE="$KIT_DIR/templates/bin/rp-worktree-hygiene"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/rp-worktree-hygiene-test.XXXXXX")"
START_DIR="$(pwd)"
CHECK_SEQ=0
trap 'rm -rf "$TMPROOT"' EXIT

# run_check <dir> [args...] — run checker in <dir>, capture rc in CHECK_RC and
# stdout+stderr in CHECK_OUT (absolute path).
run_check() {
  local dir="$1"; shift
  CHECK_SEQ=$((CHECK_SEQ + 1))
  CHECK_OUT="$TMPROOT/check-$CHECK_SEQ.out"
  CHECK_RC=0
  ( cd "$dir" && bash "$HYGIENE" "$@" >"$CHECK_OUT" 2>&1 ) || CHECK_RC=$?
}

assert_rc() {
  local want="$1"
  if [[ "$CHECK_RC" -eq "$want" ]]; then
    pass "exit code $want"
  else
    fail "expected exit $want, got $CHECK_RC"
  fi
}

assert_contains() {
  local needle="$1"
  if grep -qF "$needle" "$CHECK_OUT"; then
    pass "reports: $needle"
  else
    fail "missing from report: $needle"
  fi
}

assert_not_contains() {
  local needle="$1"
  if grep -qF "$needle" "$CHECK_OUT"; then
    fail "unexpected in report: $needle"
  else
    pass "does not report: $needle"
  fi
}

gitinit() {
  git config user.email "test@example.com"
  git config user.name "test"
}

# --- Seed a bare upstream with one committed file ---------------------------
cd "$TMPROOT"
mkdir -p seed remotes
cd seed
git init -q .
gitinit
echo "base" > f.txt
git add f.txt
git commit -q -m "seed"
git branch -M main
git clone -q --bare . "$TMPROOT/remotes/upstream.git"
cd "$TMPROOT"

echo "--- scenario: clean ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/clean"
cd "$TMPROOT/clean"
gitinit
git checkout -q -b clean-feature
echo "clean feature" >> f.txt
git commit -q -am "clean feature"
git push -q -u origin clean-feature
cd "$TMPROOT"
run_check "$TMPROOT/clean" --strict --base-ref origin/main
assert_rc 0
assert_contains "Result: OK"
assert_contains "Dirty: clean"
assert_contains "Merged into base: not merged"
assert_contains "Worktrees: 1"

echo "--- scenario: dirty ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/dirty"
echo "extra" >> "$TMPROOT/dirty/f.txt"
echo "scratch" > "$TMPROOT/dirty/untracked.txt"
run_check "$TMPROOT/dirty" --strict
assert_rc 1
assert_contains "VIOLATION"
assert_contains "dirty working tree"
# informational default still exits 0 even when dirty
run_check "$TMPROOT/dirty"
assert_rc 0
assert_contains "Result: VIOLATION"

echo "--- scenario: missing upstream ---"
git init -q "$TMPROOT/no-upstream"
cd "$TMPROOT/no-upstream"
gitinit
echo "base" > f.txt
git add f.txt
git commit -q -m "init"
git branch -M main
cd "$TMPROOT"
run_check "$TMPROOT/no-upstream" --strict
assert_rc 1
assert_contains "branch has no upstream"

echo "--- scenario: merged branch ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/merged"
cd "$TMPROOT/merged"
gitinit
git checkout -q -b feature
echo "feat" >> f.txt
git commit -q -am "feature work"
git push -q -u origin feature
git checkout -q main
git merge -q --no-ff feature -m "merge feature"
git checkout -q feature
cd "$TMPROOT"
run_check "$TMPROOT/merged" --base-ref main
assert_contains "Merged into base: merged"
assert_contains "ahead 0"
run_check "$TMPROOT/merged" --strict --base-ref main
assert_rc 1
assert_contains "already merged into canonical base"

echo "--- scenario: not merged branch ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/unmerged"
cd "$TMPROOT/unmerged"
gitinit
git checkout -q -b wip
echo "wip" >> f.txt
git commit -q -am "wip work"
cd "$TMPROOT"
run_check "$TMPROOT/unmerged" --base-ref main
assert_contains "Merged into base: not merged"

echo "--- scenario: detached HEAD ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/detached"
cd "$TMPROOT/detached"
git checkout -q --detach HEAD
cd "$TMPROOT"
run_check "$TMPROOT/detached" --strict
assert_rc 1
assert_contains "detached HEAD"

echo "--- scenario: multiple worktrees on same branch ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/multi"
cd "$TMPROOT/multi"
gitinit
git checkout -q -b shared
echo "shared" >> f.txt
git commit -q -am "shared branch"
git worktree add -q --force "$TMPROOT/multi-second" shared
cd "$TMPROOT"
run_check "$TMPROOT/multi" --strict
assert_rc 1
assert_contains "checked out in 2 worktrees"

echo "--- scenario: prunable worktree metadata ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/prunable"
cd "$TMPROOT/prunable"
gitinit
git checkout -q -b doomed
echo "doomed" >> f.txt
git commit -q -am "doomed branch"
git checkout -q main
git worktree add -q "$TMPROOT/doomed-wt" doomed
rm -rf "$TMPROOT/doomed-wt"
cd "$TMPROOT"
run_check "$TMPROOT/prunable"
assert_contains "Prunable worktree metadata: 1"

echo "--- simulation A: two sessions, isolated branches (safe) ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/sim-a"
cd "$TMPROOT/sim-a"
gitinit
git worktree add -q -b session-a "$TMPROOT/sim-a-session-a" origin/main
git worktree add -q -b session-b "$TMPROOT/sim-a-session-b" origin/main
git -C "$TMPROOT/sim-a-session-a" branch --set-upstream-to=origin/main session-a >/dev/null
git -C "$TMPROOT/sim-a-session-b" branch --set-upstream-to=origin/main session-b >/dev/null
echo "a" >> "$TMPROOT/sim-a-session-a/f.txt"
git -C "$TMPROOT/sim-a-session-a" commit -q -am "session a"
echo "b" >> "$TMPROOT/sim-a-session-b/f.txt"
git -C "$TMPROOT/sim-a-session-b" commit -q -am "session b"
cd "$TMPROOT"
run_check "$TMPROOT/sim-a-session-a" --strict --base-ref main
assert_rc 0
assert_contains "Result: OK"
run_check "$TMPROOT/sim-a-session-b" --strict --base-ref main
assert_rc 0
assert_contains "Result: OK"

echo "--- simulation B: two sessions, same branch (collision) ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/sim-b"
cd "$TMPROOT/sim-b"
gitinit
git checkout -q -b contested
echo "c" >> f.txt
git commit -q -am "contested"
git worktree add -q --force "$TMPROOT/sim-b-second" contested
cd "$TMPROOT"
run_check "$TMPROOT/sim-b-second" --strict
assert_rc 1
assert_contains "checked out in 2 worktrees"

echo "--- checker is non-destructive ---"
git clone -q "$TMPROOT/remotes/upstream.git" "$TMPROOT/nondestructive"
before_status="$(git -C "$TMPROOT/nondestructive" status --porcelain)"
before_wt="$(git -C "$TMPROOT/nondestructive" worktree list --porcelain | grep -c '^worktree ')"
run_check "$TMPROOT/nondestructive" --strict
after_status="$(git -C "$TMPROOT/nondestructive" status --porcelain)"
after_wt="$(git -C "$TMPROOT/nondestructive" worktree list --porcelain | grep -c '^worktree ')"
if [[ "$before_status" == "$after_status" && "$before_wt" == "$after_wt" ]]; then
  pass "checker leaves worktree and repo state unchanged"
else
  fail "checker modified worktree/repo state"
fi

# --- cleanup ---
cd "$START_DIR"
rm -rf "$TMPROOT"
trap - EXIT

if declare -F finish >/dev/null 2>&1; then
  finish
fi
