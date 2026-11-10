# 10. Configure the system layer with Ansible

## Status

Accepted

## Context

penguin, the Chromebook's Linux environment, has two layers to configure.
The home layer is dotfiles, secrets, and user units. The system layer is apt
sources and packages, files under `/etc`, and system units. chezmoi owns both.
Its bootstrap passes install the system layer with `sudo`, in about 450 lines
of bash and config. Every write under `/etc` needs its own hand-written guard,
and nothing catches a write without one.

chezmoi's
[design FAQ](https://www.chezmoi.io/user-guide/frequently-asked-questions/design/#can-i-use-chezmoi-to-manage-files-outside-my-home-directory)
says chezmoi "is explicitly not a full system configuration management tool."
It discourages managing files outside home beyond installing packages, and
names Puppet, Chef, Ansible, and Salt as "much better suited."

A rebuild from scratch lands on Baguette, the containerless Crostini VM.
ChromeOS installs it by default from M147, and penguin runs M156. Baguette
installs Debian trixie, so any option has to work there.

An option qualifies only if it passes three criteria:

- A blank host reaches the target state in few, repeatable steps.
- CI rebuilds from scratch and proves the result.
- Renovate tracks every pin, and CI is strong enough for automerge.

Five more criteria rank the qualifying options against each other:

- Congruence: "maintaining production hosts in complete compliance with a
  fully descriptive baseline"
  ([Traugott and Brown](https://www.usenix.org/legacy/publications/library/proceedings/lisa02/tech/full_papers/traugott/traugott_html/index.html)).
- Fit to the hand: how the configuration reads and writes.
- Simplicity.
- Purpose: the tool's own stated domain covers the job.
- Fit to the platform.

Bootstrap prerequisites and migration cost only break ties.

Three of the six options fail to qualify:

- **A system image built in CI** fails the rebuild and Renovate criteria. Home
  sits on the same disk as the system in both Crostini and Baguette, so
  replacing the image wipes home. Renovate can't see the Debian suite or the
  ChromeOS package repository the image builds from.
- **home-manager with numtide system-manager on Debian** fails the Renovate
  criterion. Renovate's `nix` manager is in beta and off by default, and it
  updates `flake.lock` only through lock file maintenance. Outside NixOS, the
  Nix build of 1Password's desktop app also loses its browser extension and
  system authentication links
  ([NixOS wiki](https://wiki.nixos.org/wiki/1Password)), so it would stay on
  apt.
- **NixOS as the Baguette guest, with home-manager** fails the Renovate
  criterion for the same reason, and fits the platform worst. Only a developer
  README documents loading a custom Baguette image, and it warns the
  instructions may change. The NixOS image comes from a community flake. It's
  the only fully congruent option.

Three options qualify:

- **chezmoi for both layers.** The system layer is outside chezmoi's purpose,
  and its bash passes carry the hand-written guards.
- **chezmoi for home, Ansible for the system layer.** Ansible's modules
  describe state, and handlers restart a service when its config changes.
  Renovate tracks `ansible-core` through the host-tool installer and Galaxy
  roles through `requirements.yml`.
- **Ansible for both layers.** Ansible can manage dotfiles, but chezmoi's FAQ
  calls whole-system tools "large systems" for that job. chezmoi reads secrets
  through the 1Password desktop app and decrypts the age-encrypted file.
  Ansible would need `community.sops` and lookups through `op` to do the same.

Fit to the hand, judged from side-by-side samples of the same configuration in
each qualifying option:

- Prefers a literal file over a file's syntax restated as data.
- Prefers a maintained module over a unit written by hand.
- Prefers packages pinned by a lockfile over floating apt packages, and
  accepts floating with unattended upgrades.
- Rates a literal dotfile and a module equally.

## Decision

chezmoi configures the home layer. A local Ansible playbook configures the
system layer: apt sources and packages, files under `/etc`, and system units.

Ansible owns the system layer on purpose and fit to the hand. The system layer
is outside chezmoi's purpose, and maintained modules and roles do the work of
hand-written units and guards. chezmoi owns the home layer because the two
tools fit the hand equally well there, and migration cost breaks the tie.

- `chezmoi apply` is the one command. A `run_before_` pass runs the playbook,
  so packages the home layer needs exist before its files and units.
- `ansible-core` installs like every other host tool, through the installer
  [ADR 0009](0009-install-pinned-tools-through-mise.md) names.
- A maintained Galaxy role, pinned in `requirements.yml`, configures what it
  covers. Built-in modules configure the rest.
- The playbook copies literal files from `etc/`, which mirrors their paths
  under `/etc`. `etc/` holds only files no role owns.
- The playbook's variables hold the apt package list.

Revisit and prefer NixOS with home-manager when both of these hold:

- Renovate's `nix` manager leaves beta and automerges `flake.lock` updates.
- Google documents loading a custom Baguette image.

## Consequences

- Ansible's modules and handlers guard `/etc`, and `backup: true` keeps the
  previous copy of a replaced file.
- `--check --diff` previews the system layer before it changes. Check mode
  can't predict what a `command` or `shell` task does, so the playbook avoids
  those modules.
- The bootstrap needs `ansible-core` and a Python newer than bookworm's 3.11,
  such as trixie's 3.13.
- A version is a Galaxy role's only pin. A replaced role release installs
  without complaint, unlike a tool pinned in `mise.lock`.
- The system layer is convergent. A package or file dropped from the playbook
  stays on the host until a task removes it.
- A role may render a config file from variables, so that file is data rather
  than a literal file.
