---
name: renovate
description: Audit, write, or revise renovate.json. Use when adding Renovate to a repo, troubleshooting unexpected (or missing) update PRs, or evolving an existing config. Applies the config:best-practices preset, explicit baseBranchPatterns/reviewers, and pre-commit manager opt-in.
---

# Renovate

Schema: <https://docs.renovatebot.com/renovate-schema.json>

## Defaults

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:best-practices"],
  "baseBranchPatterns": ["<default-branch>"],
  "reviewers": ["<owner>"],
  "pre-commit": { "enabled": true }
}
```

- `config:best-practices` — adds `helpers:pinGitHubActionDigests` (action SHA pinning) and OpenSSF scorecard alerts on top of `config:recommended`. Default for all repos.
- `baseBranchPatterns` — set to the repo's actual default branch (`main`, `master`, `trunk`, …), not a hard-coded value. Auto-detected if omitted; explicit is more portable across forks.
- `reviewers` — without it, Renovate PRs land silent. Use `assignees` instead if you only want a creation-time ping (no rebase notifications).
- `pre-commit: { enabled: true }` — opt-in manager, enabled unconditionally. No-op when `.pre-commit-config.yaml` is absent (manager only acts on that file pattern); replaces the need for pre-commit.ci where the file does exist.

## Custom regex managers

For version pins inside scripts, KDL, etc.:

```json
{
  "customType": "regex",
  "managerFilePatterns": ["/^script/install/<tool>$/"],
  "matchStrings": ["<TOOL>_VERSION=\"(?<currentValue>v[\\d.]+)\""],
  "depNameTemplate": "<owner>/<tool>",
  "datasourceTemplate": "github-releases"
}
```

- `managerFilePatterns` (renamed from `fileMatch`): wrap regex in `/.../`; bare strings are globs.
- For URL-embedded versions, capture both `depName` and `currentValue` in `matchStrings` — no `depNameTemplate` needed.
- One manager per `*_VERSION=` pattern; group only when the file shape is identical.

## Dashboard reading

Renovate opens a "Dependency Dashboard" issue. Read it before assuming a bug:

- **Detected Dependencies** without `[Updates: ...]` = already current. Not a bug.
- **Repository Problems** — investigate. "Base branch does not exist" usually means a stale config reference or a transient mid-run state.
- **Config Migration Needed** — Renovate offers an automated PR for field renames (e.g. `fileMatch` → `managerFilePatterns`, `baseBranches` → `baseBranchPatterns`). Tick the checkbox or hand-migrate.
- **Open** — pending PRs; the per-row checkboxes force a rebase/retry.

## Procedure

1. Read `renovate.json` if present. Note the repo's default branch (`git symbolic-ref refs/remotes/origin/HEAD` or the GitHub setting).
2. **Greenfield** — write the Defaults block; fill `<owner>` and `<default-branch>`. Add custom regex managers for shell-script `*_VERSION=` pins or hard-coded release URLs.
3. **Audit existing** — walk the Defaults block and the custom-managers conventions; flag drift (still on `config:recommended`, missing `reviewers`, hard-coded `baseBranchPatterns` not matching the actual default, leftover deprecated fields like `fileMatch` or `baseBranches`, ungoverned `*_VERSION=` pins).
4. Surface findings before editing. Apply only after scope is agreed.
