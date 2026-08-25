# Adjust the foot terminal

foot is the Wayland terminal on this host, built from source by
`script/install/foot` and configured by `dot_config/foot/foot.ini`. Its
colors follow daylight: light after sunrise, dark after sunset, computed
locally.

This covers changing when the theme flips, forcing a theme, the terminfo
gap over SSH, and replacing the font. It assumes you have already run
`chezmoi apply`. The comment at the top of `script/install/foot` covers why
the build is from source.

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

## Check what happens when you travel

The switch follows ChromeOS's timezone. ChromeOS pushes it into the container
over maitred's `SetTimezone`, which rewrites `/etc/localtime`;
`foot-theme-auto` re-reads that every run, so a new timezone takes effect
within five minutes of landing. It needs ChromeOS's own timezone set to
update automatically. A manually pinned one never changes, and neither will
the theme.

Coordinates come from the timezone's entry in the zone tables, which is its
representative city rather than where you are. Crossing timezones is
therefore accurate, but a long trip inside one is off by however far you are
from that city: Edinburgh runs about 40 minutes from London's sunset in June,
Houston about an hour from Chicago's in December, and Kashgar over three
hours from Shanghai's, China being a single timezone.

Preview any zone without changing the system one:

```bash
TZ=America/Chicago foot-theme-auto --dry-run
```

## Force a theme now

Signals reach running windows directly, which is also what the timer does:

```bash
pkill -USR1 foot     # dark
pkill -USR2 foot     # light
```

Windows opened afterward read `initial-color-theme` from
`~/.config/foot/theme-state.ini`, so pin a theme across new windows by editing
that file. The timer rewrites it only when the computed theme changes, so
either edit survives until the next sunrise or sunset.

## Fix a broken remote session

bookworm's `ncurses-term` ships only the `foot+base` fragment, not the `foot`
entry, so `TERM=foot` doesn't resolve on a stock Debian 12 host. Locally that
is covered: foot exports `$TERMINFO` pointing into its own prefix. The
variable doesn't survive SSH, so remote curses programs lose color and
cursor addressing.

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

Check any replacement for `U+E0B0`, the Powerline separator
`zellij-rate-limit-status` draws. JetBrains Mono is the only font on this host
that covers it. A font that lacks it produces no error: fontconfig substitutes
a Unifont bitmap, and the separator renders as a mismatched blob.

```bash
fc-list ':charset=e0b0' family    # fonts that can draw the separator
fc-list : family | grep -i mono   # what is installed
```

A face that doesn't cover it can still be the primary, since foot searches
the list in order, per glyph:

```ini
font=Some Other Mono:size=11, Symbols Nerd Font Mono:size=11
```
