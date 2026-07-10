# Issue Governance

Retailpulses uses Issue-first development for mergeable engineering work.

Exploration and local investigation can happen before an Issue. Mergeable coding cannot start without a compliant Issue. Emergency hotfixes may create a minimal Issue first, but the Issue must be corrected before PR merge.

## Source Of Truth

`retailpulses/rp-governance-kit` is the central governance source for Retailpulses repositories.

The organization `retailpulses/.github` repository may provide default GitHub Issue templates, PR template fallback, and community files. It is not the source of truth for active governance logic, reusable workflows, agent commands, rollout scripts, or engineering standards.

If repo-local governance files and this central governance kit conflict, agents must stop and report the conflict instead of guessing.

## Issue Creation Rule

Do not create normal development Issues with raw:

```bash
gh issue create --body "..."
```

Raw Issue bodies bypass repo/org Issue templates and central governance rules. They also make it easy to miss system impact, data model impact, documentation requirements, and acceptance criteria before implementation begins.

Agents must create Issues using one of:

1. `bin/rp-issue-create`
2. The repository GitHub Issue Form/template through the GitHub UI
3. An explicit user-approved exception

If an Issue is created outside governance format, it must be corrected before coding begins.

## Creating An Issue

Use the repo-local command installed by the governance kit:

```bash
bin/rp-issue-create feature
bin/rp-issue-create bug
bin/rp-issue-create architecture
bin/rp-issue-create data-model
bin/rp-issue-create docs
bin/rp-issue-create workflow
```

The command generates `.tmp/issue-draft.md` with the required governance sections:

- Problem / Opportunity
- Proposed Solution
- Current State
- Scope
- Out of Scope
- User Workflow Impact
- Data Model Impact
- Supabase Impact
- Runtime / Infrastructure Impact
- Cloudflare Dependency
- Baserow Dependency / Legacy Impact
- Documentation Requirement
- Acceptance Criteria
- Risks / Open Questions

Review and edit the draft before submission. The command prints the exact suggested `gh issue create --body-file` command. It does not submit by default.

To submit through the governed entrypoint:

```bash
bin/rp-issue-create feature --title "Short issue title" --submit
```

`--submit` only works when the generated body passes local validation. Low-structure Issues are blocked unless `--force` is explicitly used. When `--force` is used, the generated Issue body includes a governance exception warning.

## Auditing An Existing Issue

Before coding starts, run:

```bash
bin/rp-issue-audit <issue-number>
```

The audit checks for required governance sections and warns when impact keywords suggest Cloudflare, Supabase, Baserow, frontend, or data model impact was not addressed.

Results:

- `PASS` - required governance sections are present.
- `WARN` - required sections are present, but impact wording may be inconsistent.
- `FAIL` - required governance sections are missing.

To generate a correction draft:

```bash
bin/rp-issue-audit <issue-number> --fix-draft
```

This creates:

```text
.tmp/issue-correction-<issue-number>.md
```

Review and edit the correction draft, then update the Issue explicitly:

```bash
gh issue edit <issue-number> --body-file .tmp/issue-correction-<issue-number>.md
```

`rp-issue-audit` never modifies an Issue by default. It only updates the Issue when `--apply` is explicitly provided.

## Starting Work

Use:

```bash
bin/rp-issue-work <issue-number>
```

`rp-issue-work` runs the Issue audit before preparing the work brief. If the Issue fails governance audit, it stops before coding and generates a correction draft.

Coding must not start from a non-compliant Issue. Correct the Issue first, then rerun `bin/rp-issue-work <issue-number>`.

Only use this override with explicit approval:

```bash
bin/rp-issue-work <issue-number> --allow-noncompliant-issue
```

## Closing Out Work

Before opening a PR, run:

```bash
bin/rp-issue-closeout <issue-number>
```

The generated PR summary includes:

```text
Issue governance:
- Issue created with rp-issue-create or approved template: yes/no/unknown
- Issue audit passed before work: yes/no
- Missing governance fields corrected: yes/no/not needed
```

If the status is unknown, the PR summary flags it for Jim review.

## Exceptions

Exceptions are allowed only when they are explicit and narrow.

- Exploration and local investigation can happen before an Issue.
- Mergeable coding cannot start without a compliant Issue.
- Emergency hotfixes may create a minimal Issue first, but the Issue must be corrected before PR merge.
- A user may explicitly approve an exception. The Issue body must record that exception when `--force` is used.

The v1 enforcement path is intentionally lightweight:

- PR issue-link check remains blocking.
- Docs-impact check remains blocking.
- Issue governance audit is enforced through `rp-issue-work` and `rp-issue-closeout`.
- Issue audit is not a blocking GitHub Action in v1.
