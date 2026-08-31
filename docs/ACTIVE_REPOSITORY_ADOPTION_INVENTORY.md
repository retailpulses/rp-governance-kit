# Active Repository Adoption Inventory

**Purpose:** Track adoption of worktree/session isolation governance under `retailpulses/inbox#65`.
**Authority:** `retailpulses/rp-governance-kit`
**Last authenticated refresh:** 2026-08-31

The canonical policy is [`WORKTREE_AND_SESSION_GOVERNANCE.md`](WORKTREE_AND_SESSION_GOVERNANCE.md). This inventory is a rollout record, not the policy source.

## Status Contract

- `adopted`: repository-owned PR merged; checker, managed reference, and local declaration verified; owner confirms use.
- `planned`: accountable owner and governed Issue assigned; repository PR remains pending.
- `exception`: approved non-adoption with reason and review date.

An artifact detected on a branch is not sufficient for `adopted`. Exact merged SHA and repository owner acceptance are required.

## Adoption Rows

| repo | base | status | installed ref | checker | reference | local declaration | owner / Issue | notes |
|------|------|--------|---------------|---------|-----------|-------------------|---------------|-------|
| retailpulses/.github | main | planned | | | | | Engineering / inbox#65 | Verify whether organization metadata should be an exception |
| retailpulses/Archon | dev | planned | | | | | Engineering / inbox#65 | Canonical-base deviation |
| retailpulses/CatalogSync | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/OrderMgmt | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/RPagentOS | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/amazonops | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/backoffice | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/boutique-listing | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/homebliss-rustdesk | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/homebliss-vpn | feat/initial-implementation | planned | | | | | Engineering / inbox#65 | Verify default-branch intent before rollout |
| retailpulses/homepage | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/inbox | main | planned | | | | | Engineering / inbox#65 | Governance tracker; verify whether exception is appropriate |
| retailpulses/inquiry-automation | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/mercariops | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/ops-portal | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/rakutenops | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/retailpulses-tool-services | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/rp-governance-kit | main | planned | issue-65 branch | yes | yes | yes | Engineering / inbox#65 | Central PR in progress |
| retailpulses/rpPromotion | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/skills | main | planned | | | | | Engineering / inbox#65 | |
| retailpulses/ticket-handling | main | planned | | | | | Engineering / inbox#65 | Dirty/ownership-unknown checkout: inventory only until resolved |
| retailpulses/workers | main | planned | | | | | Engineering / inbox#65 | |

Source: authenticated `gh repo list retailpulses --limit 200 --json name,isArchived,defaultBranchRef`; archived repositories are excluded.

## Refresh Procedure

1. Refresh active repositories and default branches:

   ```bash
   gh repo list retailpulses --limit 200 --json name,isArchived,defaultBranchRef \
     --jq '.[] | select(.isArchived == false) | [.name,.defaultBranchRef.name] | @tsv'
   ```

2. Inspect the default branch for `bin/rp-worktree-hygiene`, `docs/18_WORKTREE_AND_SESSION_GOVERNANCE.md`, `governance/local.yaml`, and `.github/governance-ref.txt`.
3. Update a row only from merged default-branch evidence. Record the exact SHA and repository PR.
4. Never run the installer against a dirty local checkout. Rollout uses the installer's disposable clone and repository-owned PR flow.

## Change Log

- 2026-08-31: Created authenticated baseline of 22 active repositories; all rollout targets remain planned until repository-owned PR acceptance.
