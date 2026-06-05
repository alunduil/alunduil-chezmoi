# Architecture

Background and rationale for how this repo is shaped. For step-by-step setup, see [tutorials/bootstrap.md](../tutorials/bootstrap.md); for task-shaped how-tos, see [how-to/](../how-to/).

## At a glance

[C4](https://c4model.com) Container view, steady state—bootstrap-only edges (password-manager → age key) are covered in prose below.

```mermaid
C4Container
    title Container view: alunduil-chezmoi on a host

    Person(user, "User", "alunduil")
    System_Ext(github, "GitHub", "git remote")

    System_Boundary(host, "Debian/Crostini host") {
        Container(source, "Source clone", "git working tree", "Where edits happen")
        Container(apply, "Apply clone", "~/.local/share/chezmoi", "What chezmoi reads on diff/apply")
        Container(home, "Deployed files", "$HOME/{.config,.gnupg,.ssh,.local/bin,...}", "Written by chezmoi apply, age-decrypted on the way in")
    }

    Rel(user, source, "edits, commits")
    Rel(source, github, "push")
    Rel(github, apply, "pull")
    Rel(apply, home, "chezmoi apply")
```

## Source vs. apply clone

chezmoi separates the *source* (this checkout) from the *applied clone* at `~/.local/share/chezmoi`. `chezmoi diff` and `chezmoi apply` read the apply clone, not the working tree, so edits here only take effect after they're committed and the apply clone is updated. Use `chezmoi diff --source-path .` to preview from this checkout.

The split exists so a half-finished edit in the dev clone can't corrupt a live `chezmoi apply` mid-keystroke. The cost is one extra step (commit + pull) before changes go live, which is small in exchange for an always-coherent apply path.

## Ordered idempotent bootstrap

Bootstrap lives in `run_once_before_NN-*.sh.tmpl` scripts. Each script is responsible for one logical concern (system packages, language toolchains, third-party binaries, login-required tools, automatic security updates, etc.) and is safe to re-run.

- **Idempotent** because chezmoi's `run_once_before` hashes the rendered script and only executes when the hash changes. A re-run on the same content is a no-op; a re-run after a content change re-executes. Scripts must therefore tolerate "already installed" without bailing.
- **Numerically ordered** because some installs depend on others (for example, ghcup must exist before `cabal` can build anything). The two-digit prefix is a stable sort key, not a reservation system—gaps are fine.
- **One concern per script** so a failed run names its own scope. Scripts are grouped by product family, not install mechanism—a tool that needs both `apt` and a binary download lives together, not split across the apt and download passes.

Tool versions live in `script/install/*` (one script per tool, each pinning its own `*_VERSION`) and are reused by both bootstrap and CI; there's exactly one place to bump. Zellij *plugins* (`zellaude`, `zjstatus`) are pinned as alias tags in `dot_config/zellij/config.kdl` because the plugin registry is independent of the binary.

## Layered trust: Everything behind age

Long-lived secrets are stored as age-encrypted blobs in the source tree and unlocked at `apply` time:

- **age key** lives at `~/.config/chezmoi/key.txt` and is restored from a password manager on a fresh host. It's the one out-of-band secret the bootstrap needs.
- **GPG** signs commits. The secret key ships as an age-encrypted blob in `private_dot_gnupg/`; trust chain is *age key + GPG passphrase*.
- **SSH** keys (`~/.ssh/{id_rsa,config}`) ship the same way under `private_dot_ssh/`; trust chain is just the age key. This is what makes `chezmoi init --apply` over HTTPS bootstrap straight into a working SSH-to-GitHub state.

Age handles "secrets at rest in a public-ish git repo" cleanly but can't sign commits or authenticate to SSH servers. GPG and SSH each need somewhere safe to live. Putting both behind the same age-key recovery flow means a fresh host needs exactly one out-of-band secret to bootstrap everything else. The paper-key backup (see [how-to/pgp-signing.md](../how-to/pgp-signing.md)) is the independent fallback if both clouds and repo are lost together.

## `gh` shim

`dot_local/bin/executable_gh` shadows system `gh` to enforce `--draft` on `gh pr create`. The shim exists because Claude Code opens PRs through `gh`, and the project rule is "every PR opens as draft, human promotes to ready." Enforcing this in a wrapper rather than via memory keeps the rule load-bearing even when memory slips. `GH_DRAFT_GUARD=off` overrides for the rare manual case.

`gh` extensions install in `run_once_before_05-*` alongside other bespoke installers, not script 02—they're managed by `gh extension`, not the `script/install/` download-and-verify pattern, so they don't fit that script's shape. Version pin lives inline (for example, `GH_POI_VERSION`).

## Two `CLAUDE.md` files

Two files, two audiences:

- `CLAUDE.md` (this repo's root) is loaded into Claude's context every relevant turn when editing the chezmoi *source*. It's optimised for tokens, not readability—terse rules, no decorative prose.
- `dot_claude/CLAUDE.md` deploys to `~/.claude/CLAUDE.md` on apply and is loaded into Claude's context for *every* project on this host. Cross-cutting defaults live there.

Editing the deployed file directly would lose the change on the next `chezmoi apply`, so the source-of-truth is always the chezmoi-managed copy. This document, by contrast, is for human contributors and is allowed to be longer and more discursive.
