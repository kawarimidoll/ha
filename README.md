# ha

Git Worktree Manager - Simple shell functions for managing git worktrees.

## Commands

| Command | Description |
|---------|-------------|
| `ha new [name]` | Create new worktree + branch (default: wip-$RANDOM) |
| `ha get <branch>` | Checkout remote branch as worktree |
| `ha extract` | Extract current branch to worktree |
| `ha mv <name>` | Rename current worktree + branch |
| `ha del [-f]` | Delete current worktree + branch |
| `ha cd` | Select worktree with fzf and cd |
| `ha home` | Go back to base directory |
| `ha use` | Checkout current commit to base |
| `ha gone` | Delete all gone worktrees + branches |
| `ha ls` | List worktrees |
| `ha copy <path>` | Copy file/dir from base to current worktree |
| `ha link <path>` | Symlink file/dir from base to current worktree |
| `ha invoke <hook>` | Run hook manually |

## Workflow

```bash
ha new              # Create worktree with temporary name (wip-12345)
# ... do your work ...
ha mv fix-login     # Rename to proper branch name
git push -u origin fix-login
# ... create PR, get reviewed, merge ...
ha del              # Delete worktree and branch
```

## Worktree Path Convention

```
/path/to/repo          # Base repository
/path/to/repo@branch   # Worktree for branch
/path/to/repo@feat/x   # Nested branch names supported
```

## Hooks

Per-repository hooks in `.ha/hooks/`:

| Hook | Timing |
|------|--------|
| `pre-new` | Before `ha new` |
| `post-new` | After `ha new` |
| `pre-get` | Before `ha get` |
| `post-get` | After `ha get` |
| `pre-extract` | Before `ha extract` |
| `post-extract` | After `ha extract` |
| `pre-del` | Before `ha del` |
| `pre-mv` | Before `ha mv` |

Pre-hooks can abort the command by exiting with non-zero status.

```bash
# .ha/hooks/post-new
ha link .envrc
ha link .claude
direnv allow .
```

## Installation

### Sheldon (zsh)

```toml
[plugins.ha]
github = "kawarimidoll/ha"
use = ["ha.sh"]
apply = ["defer"]
hooks.post = '''
zsh-defer compdef _ha ha
'''
```

### Sheldon (bash)

```toml
[plugins.ha]
github = "kawarimidoll/ha"
use = ["ha.sh"]
```

### Manual

```bash
source /path/to/ha.sh
```

## Dependencies

- bash or zsh
- git
- fzf (for `ha cd`)

## License

MIT
