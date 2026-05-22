---
name: renovate
description: Audit, write, or revise renovate.json. Use when adding Renovate, troubleshooting unexpected (or missing) update PRs, hardening against supply-chain attacks, or evolving an existing config.
---

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

- `config:best-practices` — adds `helpers:pinGitHubActionDigests` (action SHA pinning) and OpenSSF scorecard alerts on top of `config:recommended`.
- `baseBranchPatterns` — set explicitly to the repo's default branch (`main`, `master`, `trunk`, …); auto-detected otherwise, but explicit travels better across forks.
- `reviewers` — without it, Renovate PRs land silent. Use `assignees` instead if you only want a creation-time ping (no rebase notifications).
- `pre-commit: { enabled: true }` — opt-in manager; enable unconditionally. No-op without `.pre-commit-config.yaml`; replaces pre-commit.ci where the file exists.

## Supply-chain hardening

`config:best-practices` pins action SHAs and surfaces scorecard alerts but does not delay releases. Add a bake period so malicious versions get yanked before Renovate opens a PR:

```json
{
  "minimumReleaseAge": "3 days",
  "internalChecksFilter": "strict",
  "vulnerabilityAlerts": { "minimumReleaseAge": "0 days" },
  "osvVulnerabilityAlerts": true
}
```

- `minimumReleaseAge` — days between publication and PR. 3-7 is the sweet spot; catches the common attack shape (publish → community flags → upstream yanks within a day or two).
- `internalChecksFilter: "strict"` — PRs wait during the bake. Without it Renovate opens the PR immediately and labels it "pending", defeating the purpose.
- `vulnerabilityAlerts.minimumReleaseAge: "0 days"` — load-bearing carve-out so known CVEs bypass the delay. Without it, the bake delays security fixes.
- `osvVulnerabilityAlerts: true` — widens alert source beyond GitHub's advisory database to OSV.

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

## Validation

Wire `renovate-config-validator` as a pre-commit hook so schema typos, deprecated fields, and malformed custom-manager regex fail at commit time instead of surfacing as Repository Problems on the next Renovate run.

```yaml
- repo: https://github.com/renovatebot/pre-commit-hooks
  rev: <latest>
  hooks:
    - id: renovate-config-validator
      args: [--strict, --no-global]
```

- `--strict` — fail on configs that need migration (e.g. `fileMatch` → `managerFilePatterns`), not only on outright errors. Neither flag is upstream default; both go in `args`.
- `--no-global` — treat the file as repo-level config. Without it the validator interprets it as global self-hosted config and misreports repo-only fields.
- Upstream docs: <https://docs.renovatebot.com/config-validation/>.

## Dashboard reading

Renovate opens a "Dependency Dashboard" issue. Read it before assuming a bug:

- **Detected Dependencies** without `[Updates: ...]` = already current. Not a bug.
- **Repository Problems** — investigate. "Base branch does not exist" usually means a stale config reference or a transient mid-run state.
- **Config Migration Needed** — Renovate offers an automated PR for field renames (e.g. `fileMatch` → `managerFilePatterns`, `baseBranches` → `baseBranchPatterns`). Tick the checkbox or hand-migrate.
- **Open** — pending PRs; the per-row checkboxes force a rebase/retry.

## Procedure

1. Confirm any field name you plan to write against current docs at `https://docs.renovatebot.com/configuration-options/<field>/` before editing. Renames slip in regularly (`fileMatch` → `managerFilePatterns`, `baseBranches` → `baseBranchPatterns`); memory and prior commits are not authoritative.
2. Read `renovate.json` if present. Note the repo's default branch (`git symbolic-ref refs/remotes/origin/HEAD` or the GitHub setting).
3. **Greenfield** — write the Defaults block and the Supply-chain hardening block; fill `<owner>` and `<default-branch>`. Add custom regex managers for shell-script `*_VERSION=` pins or hard-coded release URLs. Add the `renovate-config-validator` pre-commit hook (see Validation).
4. **Audit existing** — walk the Defaults, Supply-chain hardening, and custom-managers conventions; flag drift (still on `config:recommended`, missing `reviewers`, hard-coded `baseBranchPatterns` not matching the actual default, leftover deprecated fields like `fileMatch` or `baseBranches`, ungoverned `*_VERSION=` pins, missing `renovate-config-validator` pre-commit hook, missing `minimumReleaseAge` bake period or `vulnerabilityAlerts` carve-out).
5. Surface findings before editing. Apply only after scope is agreed.
