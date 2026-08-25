# Adjust the foot terminal

foot is the Wayland terminal on this host, built from source by
`script/install/foot` and configured by `dot_config/foot/foot.ini`. Its
colors follow daylight: light after sunrise, dark after sunset, computed
locally.

This covers changing when the theme flips, forcing a theme, and the one
thing that breaks over SSH. It assumes you have already run `chezmoi apply`.
For why the build is from source rather than apt, read the comment at the top
of `script/install/foot`.

## Change when the theme flips

`foot-theme-auto` switches at true sunset: the sun's centre 0.833° below the
horizon, which is the figure a calendar prints as the day's sunset time.
Civil twilight, about half an hour later, is the usual alternative.

Check what the current setting resolves to:

```bash
foot-theme-auto --dry-run
# Europe/London (51.5083, -0.1253) sun +12.41 deg -> light (recorded: light)
```

The timer runs the script with no arguments, so a different threshold means
editing `ExecStart` in `dot_config/systemd/user/foot-theme-auto.service`:

```ini
ExecStart=%h/.local/bin/foot-theme-auto --horizon -6
```

The `run_after_enable-foot-theme-auto` script hashes both units, so the next
`chezmoi apply` reloads and re-enables them.

## Force a theme now

Signals reach running windows directly, which is also what the timer does:

```bash
pkill -USR1 foot     # dark
pkill -USR2 foot     # light
```

That lasts until the next daylight transition. Windows opened afterwards read
`initial-color-theme` from `~/.config/foot/theme-state.ini`, so to pin a theme
across new windows, edit that file. The timer rewrites it only when the
computed theme changes, so a manual edit survives until the next real sunrise
or sunset.

## Fix a broken remote session

bookworm's `ncurses-term` ships only the `foot+base` fragment, not the `foot`
entry, so `TERM=foot` doesn't resolve on a stock Debian 12 host. Locally this
is handled, because foot exports `$TERMINFO` pointing into its own prefix, but
that variable doesn't survive SSH and remote curses programs fall back to
dumb-terminal behaviour.

Install foot's terminfo on the remote host once:

```bash
infocmp -x foot | ssh HOST tic -x -
```

Or, for a host you don't control, override `TERM` for the session:

```bash
TERM=xterm-256color ssh HOST
```

## Change the font

`fonts-jetbrains-mono` (in `.chezmoidata/packages.yaml`) supplies the face,
set as `font=` in `dot_config/foot/foot.ini`.

Check any replacement for `U+E0B0` before switching to it. That's the
Powerline separator `zellij-rate-limit-status` draws, JetBrains Mono is the
only font on this host that has it, and a font missing it doesn't fail
loudly: fontconfig falls through to the Unifont CSUR bitmap and the separator
renders as a mismatched blob.

```bash
fc-list ':charset=e0b0' family    # fonts that can draw the separator
fc-list : family | grep -i mono   # what is installed
```

If the face you want doesn't cover it, add a fallback rather than giving up
on the font. foot searches the list in order, per glyph:

```ini
font=Some Other Mono:size=11, Symbols Nerd Font Mono:size=11
```
