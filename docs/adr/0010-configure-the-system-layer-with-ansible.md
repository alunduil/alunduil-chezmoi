# 10. Configure the system layer with Ansible

## Status

Accepted

## Context

penguin, the Chromebook's Linux environment, has two layers to configure.
The home layer is dotfiles, secrets, and user units. The system layer is apt
sources and packages, files under `/etc`, and system units. chezmoi owns both
today. Its bootstrap passes install the system layer with `sudo`, through a
guard library in `script/lib/bootstrap.sh`. The system layer has grown to
about 450 lines across four passes, ten files under `etc/`, and
`.chezmoidata/packages.yaml`.

chezmoi's
[design FAQ](https://www.chezmoi.io/user-guide/frequently-asked-questions/design/#can-i-use-chezmoi-to-manage-files-outside-my-home-directory)
says chezmoi "is explicitly not a full system configuration management tool."
It discourages managing files outside home beyond installing packages, and
names Puppet, Chef, Ansible, and Salt as "much better suited."
Every write under `/etc` needs a guard written by hand, and #1143 found four
writes without one.

A rebuild from scratch now lands on Baguette, the containerless Crostini VM.
ChromeOS installs it by default from M147, and penguin runs M156. Baguette
installs Debian trixie, so any option has to work there.

An option qualifies only if it passes three criteria:

- A blank host reaches the target state in few, repeatable steps.
- CI rebuilds from scratch and proves the result.
- Renovate tracks every pin, and CI is strong enough for automerge.

Qualifying options are then traded off on congruence, fit to the hand,
simplicity, built for the purpose, and fit to the platform. Bootstrap
prerequisites and migration cost only break ties. Congruence means
"maintaining production hosts in complete compliance with a fully descriptive
baseline"
([Traugott and Brown](https://www.usenix.org/legacy/publications/library/proceedings/lisa02/tech/full_papers/traugott/traugott_html/index.html)).

Three of the six options compared fail to qualify:

- **A system image built in CI** fails the rebuild and Renovate criteria. Home
  sits on the same disk as the system in both Crostini and Baguette, so
  replacing the image wipes home. Renovate can't see the Debian suite or the
  ChromeOS package repository the image builds from.
- **home-manager with numtide system-manager on Debian** fails Renovate.
  Renovate's `nix` manager is in beta and off by default, and it updates
  `flake.lock` only through lock file maintenance. Outside NixOS, the Nix build
  of 1Password's desktop app also loses its browser extension and system
  authentication links
  ([NixOS wiki](https://wiki.nixos.org/wiki/1Password)), so it would stay on
  apt.
- **NixOS as the Baguette guest, with home-manager** fails Renovate for the
  same reason, and fits the platform worst. Only a developer README documents
  loading a custom Baguette image, and it warns the instructions may change.
  The NixOS image comes from a community flake. It's the only fully congruent
  option.

Three options qualify:

- **chezmoi for both layers.** It isn't built for the system layer, and its
  bash passes carry the hand-written guards.
- **chezmoi for home, Ansible for the system layer.** Ansible's apt,
  `deb822_repository`, `copy`, and `systemd_service` modules describe state,
  and handlers restart a service when its config changes. `--check --diff`
  previews a change. Renovate tracks `ansible-core` through the host-tool
  installer and Galaxy roles through `requirements.yml`.
- **Ansible for both layers.** Ansible can manage dotfiles, but chezmoi's FAQ
  calls whole-system tools "large systems" for that job. The age-encrypted
  file would move to `community.sops`.

Writing the same configuration in each qualifying option measured fit to the
hand, and showed these preferences:

- A literal file over a file's syntax restated as data.
- A maintained module over a unit written by hand.
- Packages pinned by a lockfile over floating apt packages. Floating with
  unattended upgrades is still acceptable.
- No preference between a literal dotfile and a module.

## Decision

chezmoi configures the home layer. A local Ansible playbook configures the
system layer: apt sources and packages, files under `/etc`, and system units.

Ansible takes the system layer from chezmoi for two reasons. chezmoi isn't
built for it, and Ansible's maintained modules and roles replace units and
guards written by hand. Ansible doesn't take the home layer too, because a
literal dotfile and a module fit the hand equally well. Migration cost breaks
that tie. chezmoi already reads secrets through the 1Password desktop app and
decrypts the age-encrypted file. Ansible would need `community.sops` and
lookups through `op` to do the same.

- `chezmoi apply` stays the one command. A `run_before_` pass runs the
  playbook, so packages the home layer needs exist before its files and units.
- `ansible-core` installs like every other host tool, through the installer
  [ADR 0009](0009-install-pinned-tools-through-mise.md) names.
- A maintained Galaxy role, pinned in `requirements.yml`, takes over where one
  exists. Built-in modules cover the rest.
- Literal files the playbook installs live in `etc/`, mirroring their paths
  under `/etc`. The mirror holds only files no role owns.
- The apt package list moves from `.chezmoidata/` into the playbook's
  variables.

Revisit and prefer NixOS with home-manager when both of these hold:

- Renovate's `nix` manager leaves beta and automerges `flake.lock` updates.
- Google documents loading a custom Baguette image.

## Consequences

- The guard library's `/etc` writes and their `.bak` copies give way to
  Ansible's modules, handlers, and `backup: true`.
- `--check --diff` previews the system layer before it changes. Check mode
  can't predict what a `command` or `shell` task does, so tasks avoid them.
- `ansible-core` and its Python runtime join the bootstrap. Current releases
  need a newer Python than bookworm's 3.11, and trixie ships 3.13.
- A version is a Galaxy role's only pin. A replaced role release installs
  without complaint, unlike a tool pinned in `mise.lock`.
- `host-status` reads the package list from the playbook's variables.
- The system layer stays convergent. Dropping a package or file from the
  playbook leaves it on the host until a task removes it.
- A role may render a config file from variables, as `geerlingguy.docker` does
  with `daemon.json`, so that file stops being literal.
