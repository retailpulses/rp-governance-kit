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
