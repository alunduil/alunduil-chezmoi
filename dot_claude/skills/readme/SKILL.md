---
name: readme
description: Audit, write, or revise README.md. Use when creating a README, editing one, or noticing smells (missing badges, no install steps, unclear purpose, no engagement guidance). Applies ddbeck's checklist and a shields.io badge principle.
---

# README

Reference: <https://github.com/ddbeck/readme-checklist/blob/main/checklist.md>

## Checklist (condensed)

**Identify** — project name as first heading; repo/homepage URL near top; owner/author named.

**Evaluate** — describe *why* (what it achieves), not *what* (what it's made of). Active voice, second person. License named (open source) or authorized users named (closed source).

**Use** — prerequisites before install; install + basic usage, tested.

**Engage** — pointer to deeper docs (CONTRIBUTING, LICENSE, CHANGELOG, etc.) when they exist; where to get help (or explicit "no support"); how to contribute (or explicit "not accepting").

**Final** — TOC for 10+ screens; split into files past that.

## Badges (shields.io)

Each badge earns its place: real-time, decision-relevant info not already visible on the rendered page (e.g. on github.com).

Usually qualifies:

- License — `img.shields.io/github/license/<owner>/<repo>` — survives off-GitHub renders.
- Code coverage when codecov/coveralls is wired up.
- Tool/config presence (pre-commit, Renovate, Dependabot) when used.
- Single-target platform/runtime when exactly one is supported.

Usually doesn't:

- CI status — GitHub shows it on commits; multi-workflow makes "build" ambiguous. Promote only when one named workflow is the gate.
- Last commit — already on the GitHub page.
- Release version — already on the sidebar; promote when README is rendered off-GitHub (npm, mirrors).
- Dependency counters — noisy/stale. "Renovate enabled" / "Dependabot enabled" is the usable substitute.

Test: would removing this badge lose information the reader couldn't get from the page above?

## Procedure

1. Read the README.
2. Walk the checklist; note gaps.
3. Walk the badges; flag any that don't earn their place and gaps the principle implies.
4. Surface findings before editing. Apply only after scope is agreed.
