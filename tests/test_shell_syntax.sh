#!/usr/bin/env bash
# test_shell_syntax.sh — validate shell syntax of all .sh files in the kit
# shellcheck disable=SC1090

# Syntax-check all shell scripts
echo "--- Shell syntax (bash -n) ---"
SH_FILES=$(find "$KIT_DIR" -name '*.sh' -not -path '*/\.*' -not -path '*/node_modules/*' | sort)
COUNT=0

for f in $SH_FILES; do
  if bash -n "$f" 2>/dev/null; then
    pass "$(basename "$f")"
    COUNT=$((COUNT + 1))
  else
    fail "$(basename "$f") — bash -n failed"
  fi
done

echo "  Checked $COUNT shell files."

# Check installer specifically for required safety patterns
echo ""
echo "--- Installer safety patterns ---"

INSTALLER="$KIT_DIR/bin/rp-governance-install"

if [[ ! -f "$INSTALLER" ]]; then
  fail "Installer not found: $INSTALLER"
  return
fi

# Safety 1: Does not push main
if grep -q "push.*main\|push.*origin.*main" "$INSTALLER"; then
  fail "Installer should not push to main"
else
  pass "Installer does not push to main"
fi

# Safety 2: Never auto-merges (gh pr merge --auto or git merge)
if grep -qE '(pr merge.*--auto|gh pr merge.*--auto|git merge[^-])' "$INSTALLER"; then
  fail "Installer should not auto-merge"
else
  pass "Installer does not auto-merge"
fi

# Safety 3: Has --force guard for overwriting
if grep -q 'FORCE' "$INSTALLER"; then
  pass "Installer has --force guard"
else
  fail "Installer missing --force guard"
fi

# Safety 4: Skips archived repos
if grep -q 'archived\|isArchived\|is_archived' "$INSTALLER"; then
  pass "Installer skips archived repos"
else
  fail "Installer missing archived-repo check"
fi

# Safety 5: Checks for existing PRs
if grep -q 'existing_pr\|find_existing_pr' "$INSTALLER"; then
  pass "Installer checks for existing PRs"
else
  fail "Installer missing existing-PR check"
fi

# Safety 6: Does not overwrite .local.md
if grep -q '16_DATABASE_GOVERNANCE\.local\.md' "$INSTALLER"; then
  pass "Installer references 16_DATABASE_GOVERNANCE.local.md (never overwritten)"
else
  fail "Installer should reference 16_DATABASE_GOVERNANCE.local.md"
fi

# Safety 7: Dry-run mode
if grep -q 'DRY_RUN\|dry.run' "$INSTALLER"; then
  pass "Installer has dry-run mode"
else
  fail "Installer missing dry-run mode"
fi
