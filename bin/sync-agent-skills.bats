#!/usr/bin/env bats
# shellcheck disable=SC2154  # BATS_TEST_DIRNAME and BATS_TEST_TMPDIR are set by bats
# Tests for bin/sync-agent-skills. Each test gets a throwaway $HOME and fixture skills,
# so nothing touches the real ~/.agents/skills or ~/.copilot/skills.

SCRIPT="$BATS_TEST_DIRNAME/sync-agent-skills"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  SRC="$BATS_TEST_TMPDIR/src/foo"
  mkdir -p "$SRC"
  echo "---
name: foo
---" > "$SRC/SKILL.md"
  MANIFEST="$BATS_TEST_TMPDIR/manifest"
  printf '# fixture\nskill foo %s\n' "$SRC" > "$MANIFEST"
}

@test "creates links in both roots" {
  run "$SCRIPT" --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.agents/skills/foo")" = "$SRC" ]
  [ "$(readlink "$HOME/.copilot/skills/foo")" = "$SRC" ]
}

@test "check passes after sync and is idempotent" {
  "$SCRIPT" --manifest "$MANIFEST"
  run "$SCRIPT" --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  run "$SCRIPT" --check --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  [[ "$output" != *PROBLEM* ]]
}

@test "refuses to replace a real directory" {
  mkdir -p "$HOME/.agents/skills/foo"
  echo keep > "$HOME/.agents/skills/foo/mine.txt"
  run "$SCRIPT" --manifest "$MANIFEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROBLEM not-a-symlink"* ]]
  [ "$(cat "$HOME/.agents/skills/foo/mine.txt")" = keep ]
  [ "$(readlink "$HOME/.copilot/skills/foo")" = "$SRC" ]
}

@test "repairs a stale link" {
  mkdir -p "$HOME/.agents/skills" "$BATS_TEST_TMPDIR/old"
  ln -s "$BATS_TEST_TMPDIR/old" "$HOME/.agents/skills/foo"
  run "$SCRIPT" --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.agents/skills/foo")" = "$SRC" ]
}

@test "reports a dangling source" {
  "$SCRIPT" --manifest "$MANIFEST"
  rm -rf "$SRC"
  run "$SCRIPT" --check --manifest "$MANIFEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROBLEM dangling-link"* ]]
}

@test "reports a source without SKILL.md" {
  "$SCRIPT" --manifest "$MANIFEST"
  rm -f "$SRC/SKILL.md"
  run "$SCRIPT" --check --manifest "$MANIFEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROBLEM no-skill-md"* ]]
}

@test "reports a missing file entry" {
  printf 'file %s\n' "$BATS_TEST_TMPDIR/nope.md" >> "$MANIFEST"
  run "$SCRIPT" --check --manifest "$MANIFEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROBLEM missing-file"* ]]
}

@test "check writes nothing" {
  run "$SCRIPT" --check --manifest "$MANIFEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROBLEM missing-link"* ]]
  [ ! -e "$HOME/.agents/skills/foo" ]
}

@test "expands a leading tilde in manifest paths" {
  mkdir -p "$HOME/skills/bar"
  echo "---" > "$HOME/skills/bar/SKILL.md"
  printf 'skill bar ~/skills/bar\n' > "$MANIFEST"
  run "$SCRIPT" --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.agents/skills/bar")" = "$HOME/skills/bar" ]
}
