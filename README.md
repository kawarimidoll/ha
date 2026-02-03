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

## Tips

### Using `ha use` with dev server

When running dev servers in each worktree, you need to manage multiple ports (`:3000`, `:3001`, `:3002`...). Instead, run a single dev server in the base directory and use `ha use` to checkout changes from any worktree.

```bash
# In base: pnpm dev (keeps running on :3000)
ha new feature-a    # Create worktree
# ... work on feature-a ...
ha use              # Checkout to base → see changes on :3000

ha home && ha new feature-b
# ... work on feature-b ...
ha use              # Same URL :3000, different branch
```

This keeps your dev URL consistent regardless of which worktree you're working in.

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

Hooks receive `HA_BRANCH` environment variable with the target branch name.
(`ha invoke` does not set this automatically)

```bash
# .ha/hooks/pre-new
if [[ ! "$HA_BRANCH" =~ ^(feat|fix|chore)/ ]]; then
  echo "Invalid branch name: $HA_BRANCH"
  exit 1
fi
```

```bash
# .ha/hooks/post-new
ha link .envrc
ha copy .claude
direnv allow .
```

## Installation

### Sheldon (zsh)

```toml
[plugins.ha]
github = "kawarimidoll/ha"
use = ["ha.sh"]
hooks.post = '''
compdef _ha ha
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

## Similar Projects

- https://github.com/k1LoW/git-wt
- https://github.com/708u/twig
- https://github.com/mateusauler/git-worktree-switcher
- https://github.com/akiojin/gwt
- https://github.com/johnlindquist/worktree-cli
- https://github.com/coderabbitai/git-worktree-runner

## License

MIT
