# Saving state before a rebuild

Rebuilding the Chromebook's Linux environment from scratch deletes
everything in it, including home. The bootstrap restores what the repos
and 1Password hold. Use this checklist to copy the rest off the host
before the wipe. It assumes you share Google Drive with Linux.

Pick a destination folder on Drive:

```bash
DEST=/mnt/chromeos/GoogleDrive/MyDrive/rebuild-$(date +%F)
mkdir -p "$DEST"
```

## Push unfinished git work

List commits on no remote, stashes, and uncommitted changes in every
checkout and worktree:

```bash
for repo in ~/*/; do
  [ -d "$repo/.git" ] || continue
  git -C "$repo" log --branches --not --remotes --oneline | sed "s|^|$repo: |"
  git -C "$repo" stash list | sed "s|^|$repo: |"
  git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p' |
    while read -r wt; do git -C "$wt" status --short | sed "s|^|$wt: |"; done
done
```

Push or discard each line until the loop prints nothing.

## Copy Claude Code memory

Claude Code's memory lives in home and no repo holds it:

```bash
(cd ~ && tar -czf "$DEST/claude-memory.tar.gz" .claude/projects/*/memory)
```

## Confirm the age key

The bootstrap needs the age key from the password manager. Paste the
password manager's copy into `age-keygen -y`, end with Ctrl-D, and
check that it prints the `recipient` in `.chezmoi.toml.tmpl`:

```bash
age-keygen -y
```

## Export Docker volumes

List the volumes and export each one worth keeping:

```bash
docker volume ls
docker run --rm -v VOLUME:/volume:ro debian:trixie \
  tar -cz -C /volume . >"$DEST/VOLUME.tar.gz"
```

## Review the rest of `~/.local/share`

```bash
du -sh ~/.local/share/* | sort -h
```

The bootstrap reinstalls tool directories such as `mise`, `pnpm`, and
`uv`. The first section covers `git-worktrees`. Copy anything else
whose loss matters to `$DEST`.

## Take a fallback backup

In ChromeOS Settings, open **Developers → Linux development
environment → Backup & restore** and back up to Drive. The backup may
only restore into the legacy container, not into Baguette, so treat it
as a way back rather than a source for the new environment.
