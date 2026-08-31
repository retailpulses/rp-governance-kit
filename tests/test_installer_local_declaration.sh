#!/usr/bin/env bash
# Installer/local-declaration and housekeeping rendering regression checks.

INSTALLER="$KIT_DIR/bin/rp-governance-install"
LOCAL_TEMPLATE="$KIT_DIR/templates/governance/local.yaml"
HOUSEKEEPING="$KIT_DIR/templates/bin/rp-repo-housekeeping"

if grep -q 'templates/governance/local.yaml' "$INSTALLER" \
  && grep -q 'governance/local.yaml' "$INSTALLER"; then
  pass "installer manages the minimal local declaration"
else
  fail "installer must manage governance/local.yaml"
fi

if grep -q 'if \[\[ ! -f "governance/local.yaml" \]\]' "$INSTALLER"; then
  pass "installer preserves an existing local declaration"
else
  fail "installer must not overwrite an existing local declaration"
fi

if sed 's/__GOVERNANCE_REF__/reviewed-sha/g' "$LOCAL_TEMPLATE" | grep -q 'governance_version: "reviewed-sha"'; then
  pass "local declaration renders the selected governance ref"
else
  fail "local declaration ref placeholder is not renderable"
fi

if grep -Fq "printf '%b' \"\$FOLLOWUP_ACTIONS\"" "$HOUSEKEEPING"; then
  pass "housekeeping renders hyphen-prefixed follow-up text safely"
else
  fail "housekeeping must use a fixed printf format string"
fi

# --- Worktree/session governance distribution (inbox#65) ---
if grep -q 'rp-worktree-hygiene' "$INSTALLER"; then
  pass "installer distributes rp-worktree-hygiene"
else
  fail "installer must distribute rp-worktree-hygiene"
fi

if grep -q '18_WORKTREE_AND_SESSION_GOVERNANCE' "$INSTALLER"; then
  pass "installer renders the managed worktree/session reference"
else
  fail "installer must install docs/18_WORKTREE_AND_SESSION_GOVERNANCE.md"
fi

if [[ -f "$KIT_DIR/templates/docs/18_WORKTREE_AND_SESSION_GOVERNANCE.md" ]] \
  && grep -q '__REF__' "$KIT_DIR/templates/docs/18_WORKTREE_AND_SESSION_GOVERNANCE.md"; then
  pass "18_WORKTREE_AND_SESSION_GOVERNANCE.md renders the selected ref"
else
  fail "18_WORKTREE_AND_SESSION_GOVERNANCE.md must carry __REF__ placeholder"
fi

if grep -q 'worktree_session' "$LOCAL_TEMPLATE"; then
  pass "local declaration carries a worktree_session section"
else
  fail "local declaration must declare worktree_session"
fi
