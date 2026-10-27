#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GIT_GOURCE="$REPO_ROOT/dot_local/bin/executable_git-gource"

  TMPROOT="$(mktemp -d)"
  export HOME="$TMPROOT/home" XDG_CACHE_HOME="$TMPROOT/cache"
  mkdir -p "$HOME"

  # Stubs log their argv to $STUB_LOG. gh answers the commits lookup with the
  # avatar URL in $GH_AVATARS keyed by the author= email ("email=url" lines);
  # curl writes the URL it fetched as the image body.
  STUB_DIR="$TMPROOT/stubs"
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/gh" <<'STUB'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >>"$STUB_LOG"
for arg; do [[ "$arg" == author=* ]] && email=${arg#author=}; done
while IFS='=' read -r e url; do
  [[ "$e" == "$email" ]] && printf '%s\n' "$url"
done <<<"$GH_AVATARS"
exit 0
STUB
  cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
while (($#)); do
  case "$1" in -o) out=$2; shift 2 ;; -*) shift ;; *) url=$1; shift ;; esac
done
printf '%s' "$url" >"$out"
STUB
  cat >"$STUB_DIR/gource" <<'STUB'
#!/usr/bin/env bash
printf 'gource' >>"$STUB_LOG"
printf ' <%s>' "$@" >>"$STUB_LOG"
printf '\n' >>"$STUB_LOG"
printf 'frames'
STUB
  cat >"$STUB_DIR/ffmpeg" <<'STUB'
#!/usr/bin/env bash
printf 'ffmpeg stdin=%s out=%s\n' "$(cat)" "${!#}" >>"$STUB_LOG"
STUB
  chmod +x "$STUB_DIR"/*
  export STUB_LOG="$TMPROOT/stub.log" GH_AVATARS=""
  : >"$STUB_LOG"
  export PATH="$STUB_DIR:/usr/bin:/bin"

  T0=1700000000
  REPO="$TMPROOT/repo"
  git init --quiet "$REPO"
  git -C "$REPO" remote add origin "git@github.com:me/proj.git"
}

teardown() { rm -rf "$TMPROOT"; }

# commit <name> <email> <offset>: an empty commit by that author, <offset>
# seconds after T0.
commit() {
  GIT_AUTHOR_DATE="$((T0 + $3)) +0000" GIT_COMMITTER_DATE="$((T0 + $3)) +0000" \
    git -C "$REPO" -c user.name="$1" -c user.email="$2" \
    commit --allow-empty -q -m "c$3"
}

# --- seconds_per_day: fitting history into the duration ---

@test "seconds_per_day: ten days into 60 seconds is 6 per day" {
  run bash -c 'source "$1"; seconds_per_day 60 0 864000' _ "$GIT_GOURCE"
  [ "$status" -eq 0 ]
  [ "$output" = "6.000000" ]
}

@test "seconds_per_day: a span under one day counts as one day" {
  run bash -c 'source "$1"; seconds_per_day 60 100 200' _ "$GIT_GOURCE"
  [ "$output" = "60.000000" ]
}

# --- fetch_avatars: author name to cached image ---

@test "fetch_avatars: saves each author's avatar under their name" {
  commit "Ada" ada@example.com 1
  commit "bot[bot]" 1+bot[bot]@users.noreply.github.com 2
  export GH_AVATARS=$'ada@example.com=https://a/ada?v=4\n1+bot[bot]@users.noreply.github.com=https://a/bot?v=4'
  cd "$REPO"
  run bash -c 'source "$1"; fetch_avatars me/proj "$2"' _ "$GIT_GOURCE" "$TMPROOT/av"
  [ "$status" -eq 0 ]
  [ "$(cat "$TMPROOT/av/Ada.png")" = "https://a/ada?v=4&s=128" ]
  [ "$(cat "$TMPROOT/av/bot[bot].png")" = "https://a/bot?v=4&s=128" ]
}

@test "fetch_avatars: author without a GitHub account gets no image" {
  commit "Nobody" nobody@example.com 1
  cd "$REPO"
  run bash -c 'source "$1"; fetch_avatars me/proj "$2"' _ "$GIT_GOURCE" "$TMPROOT/av"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$TMPROOT/av")" ]
}

@test "fetch_avatars: cached author makes no API call" {
  commit "Ada" ada@example.com 1
  mkdir -p "$TMPROOT/av"
  : >"$TMPROOT/av/Ada.png"
  cd "$REPO"
  run bash -c 'source "$1"; fetch_avatars me/proj "$2"' _ "$GIT_GOURCE" "$TMPROOT/av"
  [ "$status" -eq 0 ]
  ! grep -q '^gh ' "$STUB_LOG"
}

# --- main flow: what reaches gource and ffmpeg ---

@test "git-gource: live window gets computed speed, title, and avatars" {
  commit "Ada" ada@example.com 0
  commit "Ada" ada@example.com 864000
  cd "$REPO"
  run "$GIT_GOURCE"
  [ "$status" -eq 0 ]
  grep -q '<--seconds-per-day> <6.000000>' "$STUB_LOG"
  grep -q '<--title> <me/proj>' "$STUB_LOG"
  grep -q "<--user-image-dir> <$XDG_CACHE_HOME/git-gource/avatars>" "$STUB_LOG"
  ! grep -q -- '<-o>' "$STUB_LOG"
}

@test "git-gource: --output pipes gource frames into ffmpeg" {
  commit "Ada" ada@example.com 0
  cd "$REPO"
  run "$GIT_GOURCE" --no-avatars -o "$TMPROOT/out.mp4"
  [ "$status" -eq 0 ]
  grep -q '<--stop-at-end>.*<-o> <->' "$STUB_LOG"
  grep -q "^ffmpeg stdin=frames out=$TMPROOT/out.mp4$" "$STUB_LOG"
  ! grep -q -- '--user-image-dir' "$STUB_LOG"
}

@test "git-gource: arguments after -- reach gource after the defaults" {
  commit "Ada" ada@example.com 0
  cd "$REPO"
  run "$GIT_GOURCE" --no-avatars -- --user-filter bot
  [ "$status" -eq 0 ]
  grep -q "<-1280x720>.*<--user-filter> <bot> <$REPO>$" "$STUB_LOG"
}

@test "git-gource: non-GitHub origin titles by directory and skips avatars" {
  git -C "$REPO" remote set-url origin "https://gitlab.com/me/proj.git"
  commit "Ada" ada@example.com 0
  cd "$REPO"
  run "$GIT_GOURCE"
  [ "$status" -eq 0 ]
  grep -q '<--title> <repo>' "$STUB_LOG"
  ! grep -q '^gh ' "$STUB_LOG"
}

@test "git-gource: non-numeric --duration is rejected" {
  run "$GIT_GOURCE" -d soon
  [ "$status" -eq 1 ]
  [[ "$output" == *"--duration must be a number"* ]]
}
