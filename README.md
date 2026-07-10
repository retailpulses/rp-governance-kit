# rp-governance-kit

Centralized governance toolkit for Retailpulses repositories.

## What it does

Standardizes Issue-first development across Retailpulses repos:

- **Issue-first workflow** — every PR must link to a GitHub Issue
- **Agent tooling** — `rp-issue-create`, `rp-issue-work`, `rp-issue-closeout` scripts
- **Docs impact tracking** — system changes without docs updates are flagged
- **Reusable CI** — central `governance-checks.yml` called by wrapper workflows

## Install

```bash
# Install into a single repo
bin/rp-governance-install retailpulses/RPagentOS

# Install with a specific ref
bin/rp-governance-install retailpulses/ticket-handling --ref v1

# Batch install from a file
bin/rp-governance-install --repos repos.txt

# Dry run (see what would happen)
bin/rp-governance-install retailpulses/RPagentOS --dry-run
```

## Structure

```
rp-governance-kit/
├── .github/workflows/
│   └── governance-checks.yml          # Central reusable workflow (workflow_call)
├── templates/
│   ├── bin/                           # Agent scripts installed into target repos
│   │   ├── rp-issue-create
│   │   ├── rp-issue-work
│   │   └── rp-issue-closeout
│   ├── docs/                          # Docs templates
│   │   ├── 00_CURRENT_STATE.md
│   │   └── 05_DECISION_LOG.md
│   └── github/
│       ├── pull_request_template.md   # PR template
│       └── workflows/
│           └── governance-checks-wrapper.yml  # Thin wrapper for target repos
├── bin/
│   └── rp-governance-install          # Installer script
└── README.md
```

## Safety

- Never pushes to `main` directly
- Never auto-merges
- Never overwrites repo-specific docs without `--force`
- Skips archived repos
- Checks for existing governance PRs before opening duplicates
