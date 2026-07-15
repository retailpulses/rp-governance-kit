# rp-governance-kit

Centralized governance toolkit for Retailpulses repositories.

This repository is the central governance source for Retailpulses repositories.
The organization `.github` repo may provide default GitHub templates, but governance logic, reusable workflows, agent commands, rollout scripts, and engineering standards are maintained here.

If local repo governance files and central governance conflict, agents must stop and report the conflict instead of guessing.

## What It Does

Standardizes Issue-first development across Retailpulses repos:

- **Issue-first workflow** - every mergeable PR must link to a compliant GitHub Issue.
- **Issue governance** - normal development Issues must use `bin/rp-issue-create` or an approved repo/org Issue template, not raw `gh issue create --body`.
- **Agent tooling** - `rp-issue-create`, `rp-issue-audit`, `rp-issue-work`, `rp-issue-closeout`, `rp-deploy-closeout`, and `rp-repo-housekeeping` scripts.
- **Engineering standards** - centralized templates for engineering principles, frontend, data access, platform dependencies, and Issue governance.
- **Post-deploy governance** - deploy closeout reports and repo housekeeping via GitHub-native job summaries, PR/Issue comments, or artifacts.
- **Docs impact tracking** - system changes without docs updates are flagged.
- **Reusable CI** - central `governance-checks.yml`, `database-governance-checks.yml`, and `post-deploy-governance.yml` called by wrapper workflows.
- **Database governance** - canonical organization-level database policy, domain ownership registry, migration naming/quality rules, access classes, RLS policy, and hosted write safety.
- **Rollout tooling** - installer and upgrade scripts for lightweight repo adoption.

## Issue Creation Rule

No raw `gh issue create --body` for normal development work.

Agents must create Issues using:

1. `bin/rp-issue-create`
2. The repository GitHub Issue Form/template through the GitHub UI
3. An explicit user-approved exception

If an Issue is created outside governance format, it must be corrected before coding begins.

See [docs/ISSUE_GOVERNANCE.md](docs/ISSUE_GOVERNANCE.md).

## Install

```bash
# Install into a single repo
bin/rp-governance-install retailpulses/RPagentOS

# Install a specific ref
bin/rp-governance-install retailpulses/ticket-handling --ref v1.1.0

# Batch install file
bin/rp-governance-install --repos repos.txt

# Dry run
bin/rp-governance-install retailpulses/RPagentOS --dry-run
```

## Database Governance

See [`docs/DATABASE_GOVERNANCE.md`](docs/DATABASE_GOVERNANCE.md) for the canonical organization-level database governance policy.

The policy covers:
- Domain ownership and migration authority
- Migration naming and quality standards
- Hosted write safety
- Access classes and RLS requirements
- Generated types policy
- Environment separation
- Audit cadence

Domain ownership is declared in [`docs/DATABASE_OWNERSHIP.yaml`](docs/DATABASE_OWNERSHIP.yaml).

After installation, each repository has:
- `docs/16_DATABASE_GOVERNANCE.md` — local reference pointing to the canonical policy
- `docs/16_DATABASE_GOVERNANCE.local.md` — (repo-created) repository-specific declarations
- `.github/workflows/database-governance.yml` — thin wrapper calling the central reusable workflow

## Structure

```text
rp-governance-kit/
├── .github/workflows/
│   ├── governance-checks.yml                 # Central reusable workflow (blocking)
│   ├── post-deploy-governance.yml            # Central reusable workflow (non-blocking)
│   └── database-governance-checks.yml        # Central reusable workflow (database)
├── docs/
│   ├── ISSUE_GOVERNANCE.md                   # Issue-first governance policy
│   ├── DATABASE_GOVERNANCE.md                # Canonical database governance policy
│   └── DATABASE_OWNERSHIP.yaml               # Domain ownership registry
├── templates/
│   ├── bin/                                  # Agent scripts installed into target repos
│   │   ├── rp-issue-create
│   │   ├── rp-issue-audit
│   │   ├── rp-issue-work
│   │   ├── rp-issue-closeout
│   │   ├── rp-deploy-closeout
│   │   └── rp-repo-housekeeping
│   ├── docs/                                 # Docs templates and engineering standards
│   │   ├── 00_CURRENT_STATE.md
│   │   ├── 05_DECISION_LOG.md
│   │   ├── 10_ENGINEERING_PRINCIPLES.md
│   │   ├── 11_FRONTEND_STANDARDS.md
│   │   ├── 12_DATA_ACCESS_AND_SECRETS.md
│   │   ├── 13_PLATFORM_DEPENDENCY_POLICY.md
│   │   ├── 14_ISSUE_GOVERNANCE.md
│   │   ├── 15_DEPLOYMENT_AND_HOUSEKEEPING.md
│   │   └── 16_DATABASE_GOVERNANCE.md         # Installable database governance reference
│   └── github/
│       ├── pull_request_template.md          # PR template
│       └── workflows/
│           ├── governance-checks-wrapper.yml  # Thin wrapper for target repos
│           ├── post-deploy-governance-wrapper.yml # Thin wrapper for target repos
│           └── database-governance-wrapper.yml # Thin wrapper for database checks
├── bin/
│   ├── rp-governance-install                 # Installer script
│   ├── rp-issue-create                       # Local wrapper for the template command
│   ├── rp-issue-audit                        # Local wrapper for the template command
│   ├── rp-issue-work                         # Local wrapper for the template command
│   ├── rp-issue-closeout                     # Local wrapper for the template command
│   ├── rp-deploy-closeout                    # Local wrapper for the template command
│   └── rp-repo-housekeeping                  # Local wrapper for the template command
└── README.md
```

## Safety

- Never pushes `main` directly.
- Never auto-merges.
- Never overwrites repo-specific docs without `--force`.
- Skips archived repos.
- Checks for existing governance PRs before opening duplicates.
- Keeps installed repo governance lightweight and agent-friendly.
