#!/usr/bin/env bash
# Run: bash test.sh
# Covers ha-mv keeping .git/worktrees/<id> in sync. A broken id does not fail
# loudly -- the worktree just drops out of `git worktree list` -- so it is
# asserted rather than eyeballed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ha.sh"

fails=0
tmp=

check() {
  local msg="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    echo "ok   - $msg"
  else
    echo "FAIL - $msg: want '$want', got '$got'"
    fails=$((fails + 1))
  fi
}

setup() {
  # pwd -P: on macOS mktemp hands back a symlinked path, which would not match
  # the resolved paths git reports.
  tmp="$(cd "$(mktemp -d)" && pwd -P)"
  git init -q "$tmp/base"
  git -C "$tmp/base" commit -q --allow-empty -m init
}

# Reproduce the pre-fix state: path moved to base@bar, admin dir left at base@foo.
make_stale() {
  git -C "$tmp/base" worktree add -q "$tmp/base@foo" -b foo
  git -C "$tmp/base@foo" branch -m bar
  git -C "$tmp/base@foo" worktree move "$tmp/base@foo" "$tmp/base@bar"
}

id_of() { basename "$(git -C "$1" rev-parse --git-dir)"; }
usable() { git -C "$1" status --short >/dev/null 2>&1; echo $?; }

# Each case runs in a subshell: ha mv cd's, and the temp dir differs per case.
# fails resets per case so the exit status carries that case's count alone.
(
  fails=0
  setup
  git -C "$tmp/base" worktree add -q "$tmp/base@foo" -b foo
  cd "$tmp/base@foo" || exit 1
  ha mv bar
  check "rename: id follows path" "base@bar" "$(id_of "$tmp/base@bar")"
  check "rename: worktree usable" "0" "$(usable "$tmp/base@bar")"
  check "rename: old id gone" "1" "$([[ -e "$tmp/base/.git/worktrees/base@foo" ]]; echo $?)"
  rm -rf "$tmp"
  exit $fails
) || fails=$((fails + $?))

(
  fails=0
  setup
  make_stale
  cd "$tmp/base@bar" || exit 1
  ha mv foo
  # The move alone already reconciles the id here; mv would refuse to rename a
  # dir onto itself and report failure for an operation that succeeded.
  check "stale->own id: succeeds" "0" "$?"
  check "stale->own id: id correct" "base@foo" "$(id_of "$tmp/base@foo")"
  check "stale->own id: worktree usable" "0" "$(usable "$tmp/base@foo")"
  rm -rf "$tmp"
  exit $fails
) || fails=$((fails + $?))

(
  fails=0
  setup
  make_stale
  git -C "$tmp/base" worktree add -q "$tmp/base@qux" -b qux
  cd "$tmp/base@qux" || exit 1
  # Branch foo and path base@qux -> base@foo are both free; only the stale id collides.
  ha mv foo
  check "id collision: fails" "1" "$?"
  check "id collision: branch untouched" "qux" "$(git -C "$tmp/base@qux" branch --show-current)"
  check "id collision: path untouched" "0" "$([[ -d "$tmp/base@qux" ]]; echo $?)"
  check "id collision: squatter unharmed" "0" "$(usable "$tmp/base@bar")"
  rm -rf "$tmp"
  exit $fails
) || fails=$((fails + $?))

echo
if (( fails > 0 )); then
  echo "$fails failure(s)"
  exit 1
fi
echo "all passed"
