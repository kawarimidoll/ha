---
name: ha
description: >-
  Recognize the conventions of the `ha` git-worktree manager: the base-vs-worktree
  model, the `base@branch` path convention, its commands, and `.ha/hooks/`. Use when
  working in a repository managed by ha — parallel worktree/branch work, `base@branch`
  paths that sit next to a repo, `ha new`/`ha del`/`ha get` and other `ha` commands, or
  a `.ha/hooks/` directory.
---

# ha awareness

`ha` is a set of shell functions (`ha.sh`) that manage git worktrees. A repository
using it has one **base** checkout plus sibling **worktrees** named `base@branch`.
This skill gives you the mental model so you operate correctly inside such a repo. It
is about *awareness*, not driving `ha` for the user.

## Core model

- **base vs worktree.** The base is the original clone; worktrees are extra
  checkouts of other branches. You are in a worktree when
  `git rev-parse --show-toplevel` differs from the base path.
- **Base path** = first line of `git worktree list`:
  `git worktree list | head -1 | awk '{print $1}'`.
- **Path convention `base@branch`** — a worktree lives *next to* the base, not
  inside it, at `<base>@<branch>`. Nested branch names are kept verbatim:

  ```
  /path/to/repo          # base
  /path/to/repo@fix-x    # worktree for branch fix-x
  /path/to/repo@feat/x   # worktree for branch feat/x
  ```

  This is deterministic: given the base and a branch, you can compute the worktree
  path yourself without running `ha`.

## Commands

| Command | Effect | Moves cwd? |
|---|---|---|
| `ha new [name]` | Create worktree + branch from remote HEAD (default `wip-$RANDOM`) | yes → worktree |
| `ha get <branch>` | Check out a remote branch as a worktree | yes → worktree |
| `ha extract` | Move current base branch into a worktree | yes → worktree |
| `ha mv <name>` | Rename current worktree + branch | yes → worktree |
| `ha del [-f]` | Delete current worktree + branch | yes → base |
| `ha cd` | fzf-pick a worktree and cd (interactive) | yes |
| `ha home` | cd back to base | yes → base |
| `ha use` | Check out current commit into base (detached) | no |
| `ha gone` | Delete merged worktrees/branches whose upstream is gone (unmerged skipped) | no |
| `ha ls` | List worktrees (`git worktree list`) | no |
| `ha copy <path>` | Copy a file/dir from base into current worktree | no |
| `ha link <path>` | Symlink a file/dir from base into current worktree | no |
| `ha invoke <hook>` | Run a hook manually | no |

## Operating ha as an agent

- **`cd` side effects do not reach your next command.** `ha` changes directory
  *inside a shell function*, which does not propagate to your subsequent tool calls.
  So `ha new foo` creates the worktree but leaves you in the base. Never rely on
  being "moved" into a worktree.
- **Operate a worktree by its path, in a single command.** Because the path is
  deterministic, target it directly and never split `cd` from the command that needs
  it:

  ```sh
  git -C "<base>@<branch>" status
  # or
  cd "<base>@<branch>" && <command>
  ```

  This is correct whether or not your shell keeps cwd between commands.
- **Reaching the `ha` function.** It is not defined in a non-interactive shell and
  must be sourced by absolute path. Under zsh, `source …/ha.sh && ha …` breaks (the
  trailing completion line returns a non-zero status and short-circuits `&&`); use
  `;` instead:

  ```sh
  source /abs/path/to/ha.sh; ha ls
  ```
- **Prefer raw `git worktree` for direct manipulation.** Reserve invoking `ha` for
  `ha new` / `ha get`, where the hook side effects matter (see below). Those side
  effects all run inside the single `ha new`/`ha get` call, so they work fine — you
  just are not left inside the new worktree afterward.
- **If you create a worktree without `ha`, put it at `<base>@<branch>`.** A plain
  `git worktree add <base>@<branch> <branch>` keeps `ha ls`/`gone`/`del` recognizing
  it; a path off-convention desyncs them. Note that `.ha/hooks/` will *not* run, so
  prefer `ha new`/`ha get` when a project relies on them.

## Hooks

Per-repo hooks live in `.ha/hooks/` under the base. `ha` sources the matching hook
around each command, passing the target branch as `$HA_BRANCH`.

| Hook | When |
|---|---|
| `pre-new` / `post-new` | around `ha new` |
| `pre-get` / `post-get` | around `ha get` |
| `pre-extract` / `post-extract` | around `ha extract` |
| `pre-del` | before `ha del` |
| `pre-mv` | before `ha mv` |

- **`pre-*` hooks can abort** by exiting non-zero, and may enforce rules — e.g. a
  `pre-new` that requires `feat/`, `fix/`, or `chore/` branch prefixes. Respect any
  such convention when you choose a branch name.
- **`post-*` hooks have side effects** — a common `post-new` runs `ha link .envrc`,
  `ha copy .claude`, `direnv allow`. This is why invoking `ha new` is preferable to a
  raw `git worktree add` when a project relies on those.

## Current worktrees

To see the live state of the repo, run:

```sh
git worktree list
```

(equivalently `ha ls`). Do this at the start of worktree-related work so you know
which branches already have worktrees and where they live.
