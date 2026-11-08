# Saving state before a rebuild

Before rebuilding the Chromebook's Linux environment, copy off the host
whatever the bootstrap can't restore. The rebuild deletes home along
with everything else, and the bootstrap restores only what the repos and
1Password hold. This checklist assumes you share Google Drive with
Linux. The rebuild itself is [the bootstrap](../tutorials/bootstrap.md).

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

```bash
(cd ~ && tar -czf "$DEST/claude-memory.tar.gz" .claude/projects/*/memory)
```

## Confirm the age key

The bootstrap reads the age key from the password manager, so check that
copy before the wipe. Paste it into `age-keygen -y`, end with Ctrl-D,
and compare the output with `recipient` in `.chezmoi.toml.tmpl`:

```bash
age-keygen -y
```

## Export Docker volumes

List the volumes, then export each one worth keeping, replacing
`VOLUME` with its name:

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
`uv`. Pushing git work covers `git-worktrees`. Copy anything else whose
loss matters to `$DEST`.

## Take a fallback backup

In ChromeOS Settings, open **Developers → Linux development
environment → Backup & restore** and back up to Drive. The backup may
restore only into the legacy container, so keep it for returning there
if the Baguette rebuild fails.
