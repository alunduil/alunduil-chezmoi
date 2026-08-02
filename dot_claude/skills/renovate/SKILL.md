---
name: renovate
description: Audit, write, or revise renovate.json. Use when adding Renovate, troubleshooting unexpected (or missing) update PRs, hardening against supply-chain attacks, or evolving an existing config.
---

## Defaults

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:best-practices",
    "security:openssf-scorecard",
    "customManagers:githubActionsVersions"
  ],
  "timezone": "Europe/London",
  "reviewers": ["alunduil"],
  "labels": ["dependencies"],
  "pre-commit": { "enabled": true }
}
```

- This block is identical in every repo and is a standing candidate for a shared preset (`github>alunduil/renovate-config`, a `default.json`); Renovate also checks `<owner>/renovate-config` when onboarding a new repo. Until that repo exists, keep the block inline and change it everywhere at once.
- Omit `baseBranchPatterns`. It is auto-detected, and hard-coding it is the one field that differs per repo (`main` vs `master`) — the thing that would block sharing.
- Omit `schedule` unless a repo wants batching. With a bake period the PR is already delayed, and Renovate's default `prHourlyLimit` of 2 rate-limits the rest.
- `packageRules` and `customManagers` are `mergeable: true`, so preset arrays concatenate with a repo's own rather than replacing them. `labels` and `reviewers` are not mergeable — setting them in a repo replaces the inherited value. `addLabels` is the mergeable counterpart and appends; switch the block to it if this ever moves into a shared preset, or the first repo to set its own `labels` silently drops `dependencies`.
- `labels` — Renovate's default is `[]`, so nothing is labelled without this. Anything keying off Renovate PRs depends on it: a stale sweep must carry `exempt-pr-labels: dependencies`, because closing a Renovate PR tells Renovate the version is unwanted and it will not re-offer it. `vulnerabilityAlerts` takes no `labels`, so security updates cannot be split out this way.
- `reviewers` — without it, Renovate PRs land silent. Use `assignees` instead for a creation-time ping with no rebase notifications.
- `pre-commit: { enabled: true }` — opt-in manager; enable unconditionally. No-op without `.pre-commit-config.yaml`; replaces pre-commit.ci where the file exists.
- `config:best-practices` = `config:recommended` + `docker:pinDigests` + `helpers:pinGitHubActionDigests` + `:configMigration` + `:pinDevDependencies` + `abandonments:recommended` + `security:minimumReleaseAgeNpm` + `:maintainLockFilesWeekly`. It does *not* include OpenSSF scorecard; that is `security:openssf-scorecard`, which adds a badge column to PR bodies.

## Supply-chain hardening

`config:best-practices` bakes npm releases for 3 days (`security:minimumReleaseAgeNpm`) but nothing else. Widen it to every datasource:

```json
{
  "minimumReleaseAge": "3 days",
  "osvVulnerabilityAlerts": true,
  "packageRules": [
    {
      "matchUpdateTypes": ["pin", "pinDigest", "digest", "lockFileMaintenance",
                           "lockfileUpdate", "rollback", "bump", "replacement"],
      "minimumReleaseAge": null
    }
  ]
}
```

- `minimumReleaseAge` — 3-7 days catches the common attack shape (publish → community flags → upstream yanks within a day or two).
- The carve-out is the load-bearing half. `minimumReleaseAgeBehaviour` defaults to `timestamp-required` (Renovate 42), so a release with no timestamp is treated as never stable, and `internalChecksFilter` defaults to `strict`, so no branch is ever cut. These eight update types cannot carry a timestamp, so without the carve-out they stall on a pending `renovate/stability-days` check forever — silently, since no PR appears. `config:best-practices` pulls in `:maintainLockFilesWeekly` and both digest-pinning presets, so `lockFileMaintenance`, `digest`, and `pinDigest` are always in scope.
- `osvVulnerabilityAlerts: true` — widens alerts beyond GitHub's advisory database to OSV. Defaults to `false`.
- Do *not* write `internalChecksFilter: "strict"` or `vulnerabilityAlerts: { "minimumReleaseAge": "0 days" }`. Both are already the defaults (`lib/config/options/index.ts`: `internalChecksFilter` default `strict`; the `vulnerabilityAlerts` default object contains `minimumReleaseAge: null`, force-applied over the top-level bake).
- `minimumReleaseAge: "0 days"` is identical to `null` as of Renovate 42.19.5. Prefer `null`.

## Version pins in scripts

Annotate the pin; do not write a manager per pin. One generic manager reads them all, and a new pin needs no config change:

```bash
# renovate: datasource=github-releases depName=mikefarah/yq
YQ_VERSION="v4.53.2"
```

```json
{
  "customType": "regex",
  "managerFilePatterns": ["script/install/*", ".chezmoiscripts/*.tmpl"],
  "matchStrings": [
    "# renovate: datasource=(?<datasource>[a-zA-Z0-9-._]+?) depName=(?<depName>[^\\s]+?)(?: packageName=(?<packageName>[^\\s]+?))?(?: versioning=(?<versioning>[^\\s]+?))?(?: extractVersion=(?<extractVersion>[^\\s]+?))?\\s+[A-Za-z0-9_]+?_VERSION=\"(?<currentValue>.+?)\""
  ]
}
```

- Annotation field order is fixed by the regex: datasource, depName, packageName, versioning, extractVersion, registryUrl. `datasource`, `versioning`, `extractVersion` and `registryUrl` are recognised capture-group names — no `*Template` fields needed.
- For workflow YAML (`X_VERSION: "v1"` under `env:`) extend `customManagers:githubActionsVersions` instead of writing this yourself. Hoist versions buried in `with:` inputs up to `env:` so the preset reaches them; add `extractVersion=^v(?<version>.+)$` when the consumer wants the tag without its leading `v`.
- Upstream ships equivalents for Dockerfiles, Makefiles, `*.tfvars`, `pom.xml`, and several CI formats — check `customManagers:*` before writing a regex.
- Keep a bespoke manager only where an annotation cannot go: a version embedded in a URL (capture `depName` and `currentValue` from the URL itself), or a snippet in user-facing docs where a `# renovate:` line would be copy-pasted by a reader.
- `managerFilePatterns` (renamed from `fileMatch`): bare strings are globs; wrap in `/.../` for a regex. Prefer the glob.
- Validate a new `matchStrings` against the real files before committing — the regex is ECMAScript/RE2 (no lookahead, no backreferences), and a silently non-matching manager looks exactly like a dependency with no updates.

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
- The validator does not resolve remote presets, so it cannot tell you an `extends` target is missing or that a shared preset changed under you.
- Upstream docs: <https://docs.renovatebot.com/config-validation/>.

## Dashboard reading

Renovate opens a "Dependency Dashboard" issue. Read it before assuming a bug:

- **Detected Dependencies** without `[Updates: ...]` = already current. Not a bug.
- **Pending Status Checks** — the bake period holding an update back. Permanent residents here mean a missing no-timestamp carve-out.
- **Repository Problems** — investigate. "Base branch does not exist" usually means a stale config reference or a transient mid-run state.
- **Config Migration Needed** — Renovate offers an automated PR for field renames (e.g. `fileMatch` → `managerFilePatterns`, `baseBranches` → `baseBranchPatterns`). Tick the checkbox or hand-migrate.
- **Open** — pending PRs; the per-row checkboxes force a rebase/retry.

## Procedure

1. Confirm any field name, default, or preset body you plan to rely on against the source, not memory: defaults in `lib/config/options/index.ts`, preset bodies in `lib/config/presets/internal/*.preset.ts`. Docs summaries and prior commits drift — several fields once worth writing are now defaults.
2. Read `renovate.json` if present, and any preset it extends.
3. **Greenfield** — write the Defaults and Supply-chain hardening blocks. Add `customManagers` only for pins the annotation convention cannot reach. Add the `renovate-config-validator` pre-commit hook (see Validation).
4. **Audit existing** — flag drift: fields that merely restate a default (`internalChecksFilter`, `vulnerabilityAlerts.minimumReleaseAge`, `baseBranchPatterns`), a no-timestamp carve-out that is missing or narrower than the eight update types, one manager per pin where an annotation would do, unannotated `*_VERSION=` pins (invisible to Renovate, so they look up-to-date forever), deprecated `fileMatch`/`baseBranches`, missing validator hook, missing `labels` where a workflow exempts Renovate PRs by label.
5. Surface findings before editing. Apply only after scope is agreed.
