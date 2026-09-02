# ha

Git Worktree Manager - Simple shell functions for managing git worktrees.

## Commands

| Command | Description |
|---------|-------------|
| `ha new [name]` | Create new worktree + branch (default: wip-$RANDOM) |
| `ha get <branch>` | Checkout remote branch as worktree |
| `ha pr <num\|url>` | Checkout GitHub PR as worktree (via `gh`) |
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
| `pre-pr` | Before `ha pr` |
| `post-pr` | After `ha pr` |
| `pre-extract` | Before `ha extract` |
| `post-extract` | After `ha extract` |
| `pre-del` | Before `ha del` |
| `pre-mv` | Before `ha mv` |

Pre-hooks can abort the command by exiting with non-zero status.

Hooks receive `HA_BRANCH` environment variable with the target branch name.
(`ha invoke` does not set this automatically)

Hooks can reuse each other: a `post-pr` containing `ha invoke post-get` runs the
same setup, with `HA_BRANCH` inherited.

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
- gh 2.98.0+ (for `ha pr`, which needs `gh pr checkout --worktree`)

## Development

Run the tests with:

```bash
bash test.sh
```

`test.sh` exercises `ha mv` against a throwaway repo, covering the worktree
rename, the already-reconciled id, and the admin-dir id collision. It needs
only bash and git — no test framework.

## AI Agent Skill

`skills/ha/SKILL.md` is an [Agent Skill](https://agentskills.io) that teaches AI
coding agents (Claude Code, etc.) ha's conventions — the base-vs-worktree model, the
`base@branch` path convention, the commands, and `.ha/hooks/` — so they operate
correctly in a repo managed by ha.

Install it into your personal skills dir so it applies in every project where you use
ha. The default is `~/.claude/skills/`; if you set `CLAUDE_CONFIG_DIR`, use
`$CLAUDE_CONFIG_DIR/skills/` instead.

**If you installed ha via Sheldon**, the repo is already cloned locally — no need to
clone it again. Symlink the skill from there (run `sheldon lock --update` first to
pull the latest):

```bash
mkdir -p ~/.claude/skills
ln -s "${XDG_DATA_HOME:-$HOME/.local/share}/sheldon/repos/github.com/kawarimidoll/ha/skills/ha" ~/.claude/skills/ha
```

**If you cloned the repo manually**, from the repo root:

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD/skills/ha" ~/.claude/skills/ha   # or: cp -r skills/ha ~/.claude/skills/ha
```

A symlink keeps the skill in sync as the repo updates. It activates automatically
when an agent works with worktrees or ha commands.

## Similar Projects

- https://github.com/k1LoW/git-wt
- https://github.com/708u/twig
- https://github.com/mateusauler/git-worktree-switcher
- https://github.com/akiojin/gwt
- https://github.com/johnlindquist/worktree-cli
- https://github.com/coderabbitai/git-worktree-runner

## License

MIT
