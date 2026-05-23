#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures/changelog_guard"
  HOOK="$BATS_TEST_TMPDIR/changelog-guard.sh"
  install -m 0755 "$REPO_ROOT/dot_claude/hooks/executable_changelog-guard.sh" "$HOOK"
  CHANGELOG="$BATS_TEST_TMPDIR/CHANGELOG.md"
  README="$BATS_TEST_TMPDIR/README.md"
  TODAY="$(date -u +%Y-%m-%d)"
}

# Canonical "before" file: [Unreleased] plus one past release.
write_canonical() {
  cat >"$CHANGELOG" <<'EOF'
# Changelog

## [Unreleased]

### Added
- pending feature

## [1.0.0] - 2025-01-01

### Added
- initial release
EOF
}

render() {
  sed \
    -e "s|__CHANGELOG__|$CHANGELOG|g" \
    -e "s|__README__|$README|g" \
    -e "s|__TODAY__|$TODAY|g" \
    "$FIXTURES/$1"
}

@test "allows additions under [Unreleased]" {
  write_canonical
  run "$HOOK" < <(render allow_unreleased_add.json)
  [ "$status" -eq 0 ]
}

@test "blocks future-dated version heading on Write" {
  write_canonical
  run "$HOOK" < <(render block_future_heading_write.json)
  [ "$status" -eq 2 ]
  [[ "$output" == *"future-dated version heading"* ]]
}

@test "blocks 'coming soon' phrase" {
  write_canonical
  run "$HOOK" < <(render block_phrase_coming_soon.json)
  [ "$status" -eq 2 ]
  [[ "$output" == *"pre-announcement phrase"* ]]
}

@test "blocks 'planned' phrase" {
  write_canonical
  run "$HOOK" < <(render block_phrase_planned.json)
  [ "$status" -eq 2 ]
}

@test "blocks 'upcoming' phrase" {
  write_canonical
  run "$HOOK" < <(render block_phrase_upcoming.json)
  [ "$status" -eq 2 ]
}

@test "blocks new content under released section (Edit)" {
  write_canonical
  run "$HOOK" < <(render block_released_section_edit.json)
  [ "$status" -eq 2 ]
  [[ "$output" == *"released"* ]]
}

# MultiEdit applies edits sequentially. The unreleased-only edit must pass
# while the released-section edit must block — exercises that the guard
# considers the cumulative post-edit state, not each edit in isolation.
@test "blocks released-section addition inside MultiEdit batch" {
  write_canonical
  run "$HOOK" < <(render block_released_section_multiedit.json)
  [ "$status" -eq 2 ]
  [[ "$output" == *"released"* ]]
}

@test "allows edits to non-CHANGELOG files" {
  echo "anything" >"$README"
  run "$HOOK" < <(render allow_non_changelog.json)
  [ "$status" -eq 0 ]
}

@test "allows unrelated tool calls" {
  run "$HOOK" < <(render allow_unrelated_tool.json)
  [ "$status" -eq 0 ]
}

# Moving entries into a today-dated release section is the legitimate
# release-cut flow; the content under the new heading is not "new" by
# line content, so set-diff against [Unreleased] should not flag it.
@test "allows today-dated release heading cut from [Unreleased]" {
  write_canonical
  run "$HOOK" < <(render allow_today_release.json)
  [ "$status" -eq 0 ]
}

# Locks in fail-closed on malformed input: exits 2 (block), not 1
# (warning). Guards against schema drift letting CHANGELOG edits through.
@test "blocks on malformed JSON" {
  run "$HOOK" <"$FIXTURES/malformed.json"
  [ "$status" -eq 2 ]
}
