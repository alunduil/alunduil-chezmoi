# Adjust the foot terminal

foot is the Wayland terminal on this host, installed from apt and configured
by `dot_config/foot/foot.ini`. It uses one fixed theme, Tempus Night.

This covers replacing the theme, replacing the font, and the terminfo gap over
SSH. It assumes you have already run `chezmoi apply`.

## Replace the theme

The palette is inlined in the `[colors]` section of `dot_config/foot/foot.ini`
rather than included from a file, because the Debian package ships no themes
directory.

A replacement has to meet three properties:

- Every one of the sixteen ANSI slots should clear WCAG AAA, 7:1 against the
  background. That's what lets one theme stay readable in daylight and at
  night.
- The background should be close to neutral, casting neither warm nor cool.
- All sixteen slots should be distinct. `.vimrc` sets no colorscheme, so vim
  reads its syntax colors straight off them. A theme that collapses the bright
  row onto the regular one flattens vim's highlighting; Catppuccin and
  Solarized both do.

foot publishes its themes at
<https://codeberg.org/dnkl/foot/src/branch/master/themes>. The Tempus family
is built to the contrast standard, so its other variants are the closest
alternatives.

## Replace the font

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

A face that doesn't cover it can still be the primary, since foot searches the
list in order, per glyph:

```ini
font=Some Other Mono:size=11, Symbols Nerd Font Mono:size=11
```

## Fix a broken remote session

The `foot` package depends on `foot-terminfo`, so `TERM=foot` resolves here.
A remote host lacks that terminfo unless it installs foot too, and curses
programs there lose color and cursor addressing.

Install foot's terminfo on the remote host once:

```bash
infocmp -x foot | ssh HOST tic -x -
```

Or, for a host you don't control, override `TERM` for the session:

```bash
TERM=xterm-256color ssh HOST
```
