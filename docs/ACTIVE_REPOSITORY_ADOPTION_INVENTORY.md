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
| retailpulses/.github | main | exception | n/a | n/a | n/a | n/a | Engineering / inbox#65 | Organization metadata only; no writable implementation sessions. Review 2026-11-30 |
| retailpulses/Archon | dev | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #2; merge `8ba4d4f1eee3ef9fae50d436c0c834f0d4292a89`; base `origin/dev` verified |
| retailpulses/CatalogSync | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #155; merge `2209c9d1d94686f8c3be08e7e3f9eb296e6303f6` |
| retailpulses/OrderMgmt | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #246; merge `b05c33649c43a86f8128eb5a6e0e5fc9cfcfef03`; existing local declaration preserved |
| retailpulses/RPagentOS | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #102; merge `3e925355a61dfab82628076b1e1111d65538ef0c` |
| retailpulses/amazonops | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #6; merge `e39b527f8b95079adc2e313911f5a8c8a5f0f9a4` |
| retailpulses/backoffice | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #16; merge `b9c36aa5343abdb18444eb157af438fbf7f6f3d9` |
| retailpulses/boutique-listing | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #85; merge `fdef8d4233c80b45c40085f64b0de7927aa58c64` |
| retailpulses/homebliss-rustdesk | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #3; merge `2ca8efb2a65adfd1977931ca9dcd9d475e82932c` |
| retailpulses/homebliss-vpn | feat/initial-implementation | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #5; merge `9de5d629dc3d762fa3cb9ad654e085030d123d1d`; base verified |
| retailpulses/homepage | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #3; merge `98df41bff1283b55030559d4c9e25df472aa60fd` |
| retailpulses/inbox | main | exception | n/a | n/a | n/a | n/a | Engineering / inbox#65 | Issue intake/tracking only; no product implementation sessions. Review 2026-11-30 |
| retailpulses/inquiry-automation | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #88; merge `2e713a3f75047b71bdeaa94204b4b966c4c043ce` |
| retailpulses/mercariops | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #19; merge `420d1f91993e9a3209b5eb07c2c987fc67c5bd43` |
| retailpulses/ops-portal | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #69; merge `23ffcc53a9de7297521fbd5139ac6a168ab1f96d` |
| retailpulses/rakutenops | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #11; merge `f96c108c891e39cb3f30939522555afc63b4aea1` |
| retailpulses/retailpulses-tool-services | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #6; merge `a536441ffdf3fd760858663bc7923b556b616123` |
| retailpulses/rp-governance-kit | main | adopted | source `12056e83066536fff6804209f049f6de4b107081` | yes | canonical | n/a | Engineering / inbox#65 | Central authority; PRs #63/#64; no downstream install marker required |
| retailpulses/rpPromotion | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #2; merge `ab19dead8ec46346f83290e39cd35373ae3cdf9b` |
| retailpulses/skills | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #9; merge `412abb40068811f3d88e615f12dbd6a75caa3e47` |
| retailpulses/ticket-handling | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #216; merge `9a80699db4a6d5cf7978c580f4bab3dc1cfda45c`; local dirty checkout untouched |
| retailpulses/workers | main | adopted | 12056e83066536fff6804209f049f6de4b107081 | yes | yes | yes | Engineering / inbox#65 | PR #24; merge `462e66277a0997a2a4858d7a3dec0582494568e0` |

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

- 2026-08-31: Adopted in 20 engineering repositories through repository-owned PRs; documented `.github` and `inbox` exceptions with 2026-11-30 review dates. GitHub Actions could not start during rollout because of the account billing/spending-limit state; deterministic local validation and governance-only file-scope review were recorded in #65.
