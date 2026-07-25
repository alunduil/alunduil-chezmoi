# Claude sessions on the Home Assistant SSH add-on

Bring `claude` and `gcx` up on the "Advanced SSH & Web Terminal" add-on
(Alpine/musl, amd64), with chezmoi deploying `~/.claude`. The container is
ephemeral—`/root` resets on rebuild, `/share` persists—so the bootstrap re-runs
every start and caches binaries under `/share`.

Set both options under Settings → Add-ons → Advanced SSH & Web Terminal →
Configuration.

## `packages`

Alpine runtime dependencies, reinstalled every start. `ripgrep`/`libgcc`/`libstdc++`
are `claude`'s musl runtime, `bash`/`curl` run the installers, `git`/`jq` back
chezmoi:

```yaml
packages:
  - bash
  - curl
  - git
  - jq
  - ripgrep
  - libgcc
  - libstdc++
```

## `init_commands`

chezmoi is the pivot: install it, let it deploy config and clone the source,
then install the tools that live in that source. Order matters—each step
depends on the one before:

```yaml
init_commands:
  - mkdir -p /share/claude-session/bin
  - '[ -x /share/claude-session/bin/chezmoi ] || sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /share/claude-session/bin'
  - 'CHEZMOI_ROLE=ha-terminal /share/claude-session/bin/chezmoi init --apply https://github.com/alunduil/alunduil-chezmoi.git'
  - '~/.local/share/chezmoi/script/install/gcx --bin-dir /share/claude-session/bin'
  - 'curl -fsSL https://claude.ai/install.sh | bash'
  - 'ln -sf /share/claude-session/bin/chezmoi /share/claude-session/bin/gcx ~/.local/bin/claude /usr/local/bin/'
```

- **chezmoi** caches in `/share`, so a restart skips the re-download; delete
  `/share/claude-session/bin/chezmoi` to pull a newer one.
- **`CHEZMOI_ROLE=ha-terminal`** gates the source to `~/.claude` + `~/.vimrc`:
  no Debian bootstrap, no long-lived secrets, and no age key, because nothing
  encrypted is in scope for this role.
- **`gcx`** installs from the just-cloned source, pinned and checksum-verified
  by `script/install/gcx`.
- **`claude`** floats—the native installer self-updates, and re-fetches the
  latest whenever `/root` is fresh.
- The final **symlink** puts all three on the default PATH, so the interactive
  shell finds them without a shell startup file (ha-terminal deploys none).

## Verify on first start

```bash
claude --version && gcx --version && chezmoi --version
```

Two spots depend on the add-on's runtime and are worth confirming on the first
bootstrap:

- **PATH.** The last `init_commands` step assumes `/usr/local/bin` is on PATH
  and writable. If it isn't, symlink into a directory that is.
- **Persistence.** If `/root` is wiped on every start (not just on rebuild),
  the native installer re-pulls `claude` (~270 MB) each start; `/share` already
  spares chezmoi and `gcx` that. If `/root` survives restarts, `claude` only
  does a fast update check.
