#!/usr/bin/env bash
# Git worktree helper functions
# Usage: source this file from your shell rc
# Compatible with bash and zsh

HA_VERSION="2026.02.13"

# Internal: get base worktree path
_ha_base_path() {
  git worktree list | head -1 | awk '{print $1}'
}

# Internal: get worktree path for branch
_ha_worktree_path() {
  echo "$(_ha_base_path)@$1"
}

# Internal: check if in a worktree (not base)
_ha_is_worktree() {
  [[ "$(git rev-parse --show-toplevel)" != "$(_ha_base_path)" ]]
}

# Internal: get remote HEAD (e.g., origin/main)
_ha_remote_head() {
  git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD
}

# Internal: fetch latest from remote
_ha_fetch() {
  git fetch --all --prune --quiet
}

# Internal: run hook if exists (in subshell)
# Returns: 0 if hook doesn't exist, otherwise hook's exit status
_ha_exec_hook() {
  local hook_file="$(_ha_base_path)/.ha/hooks/$1"
  [[ -f "$hook_file" ]] || return 0
  ( source "$hook_file" )
}

# Main entry point
ha() {
  local cmd="$1"
  shift 2>/dev/null
  case "$cmd" in
    new)     ha-new "$@" ;;
    get)     ha-get "$@" ;;
    extract) ha-extract "$@" ;;
    mv)      ha-mv "$@" ;;
    del)     ha-del "$@" ;;
    cd)      ha-cd "$@" ;;
    home)    ha-home "$@" ;;
    use)     ha-use "$@" ;;
    gone)    ha-gone "$@" ;;
    ls)      ha-ls "$@" ;;
    copy)    ha-copy "$@" ;;
    link)    ha-link "$@" ;;
    invoke)  ha-invoke "$@" ;;
    *)
      echo "ha $HA_VERSION"
      echo ""
      cat <<'EOF'
Usage: ha <command> [args]

Commands:
  new [name]    Create new worktree + branch and cd (default: wip-$RANDOM)
  get <branch>  Checkout remote branch as worktree
  extract       Extract current branch to worktree
  mv <name>     Rename current worktree + branch
  del [-f]      Delete current worktree + branch
  cd            Select worktree with fzf and cd
  home          Go back to base directory
  use           Checkout current commit to base
  gone          Delete all gone worktrees + branches
  ls            List worktrees
  copy <path>   Copy file/dir from base to current worktree
  link <path>   Symlink file/dir from base to current worktree
  invoke <hook> Run hook manually
EOF
      return 1
      ;;
  esac
}

# List worktrees
ha-ls() {
  git worktree list "$@"
}

# Checkout remote branch as worktree
ha-get() {
  local branch_name="$1"
  if [[ -z "$branch_name" ]]; then
    echo "Usage: ha get <branch>" >&2
    return 1
  fi

  local worktree_path="$(_ha_worktree_path "$branch_name")"

  HA_BRANCH="$branch_name" _ha_exec_hook pre-get || return 1
  _ha_fetch || return 1

  # Check if remote branch exists
  if ! git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
    echo "Error: Remote branch 'origin/$branch_name' does not exist" >&2
    return 1
  fi

  # Create worktree tracking remote branch
  git worktree add "$worktree_path" "$branch_name" || return 1

  cd "$worktree_path" || return 1

  HA_BRANCH="$branch_name" _ha_exec_hook post-get
}

# Extract current branch to worktree (from base only)
ha-extract() {
  _ha_is_worktree && { echo "Error: Already in a worktree" >&2; return 1; }

  local branch_name="$(git branch --show-current)"
  if [[ -z "$branch_name" ]]; then
    echo "Error: Not on a branch (detached HEAD)" >&2
    return 1
  fi

  local worktree_path="$(_ha_worktree_path "$branch_name")"

  HA_BRANCH="$branch_name" _ha_exec_hook pre-extract || return 1

  # Detach base first to release the branch
  git checkout --detach "$(_ha_remote_head)" || return 1

  # Then move branch to worktree
  git worktree add "$worktree_path" "$branch_name" || return 1

  cd "$worktree_path" || return 1

  HA_BRANCH="$branch_name" _ha_exec_hook post-extract
}

# Create new worktree + branch from remote-head
ha-new() {
  local branch_name="${1:-wip-$RANDOM}"

  # Validate branch name
  if ! git check-ref-format --branch "$branch_name" >/dev/null 2>&1; then
    echo "Error: Invalid branch name '$branch_name'" >&2
    return 1
  fi

  local worktree_path="$(_ha_worktree_path "$branch_name")"

  HA_BRANCH="$branch_name" _ha_exec_hook pre-new || return 1
  _ha_fetch || return 1

  # Create worktree with detached HEAD
  git worktree add --detach "$worktree_path" "$(_ha_remote_head)" || return 1

  # Move to worktree and create branch
  cd "$worktree_path" || return 1
  git switch --create "$branch_name" --no-track

  HA_BRANCH="$branch_name" _ha_exec_hook post-new
}

# Rename current worktree + branch
ha-mv() {
  local new_name="$1"
  if [[ -z "$new_name" ]]; then
    echo "Usage: ha mv <new-branch-name>" >&2
    return 1
  fi

  _ha_is_worktree || { echo "Error: Not in a worktree" >&2; return 1; }

  local current_path="$(git rev-parse --show-toplevel)"
  local new_path="$(_ha_worktree_path "$new_name")"

  HA_BRANCH="$new_name" _ha_exec_hook pre-mv || return 1

  git branch -m "$new_name" || return 1
  git worktree move "$current_path" "$new_path" || return 1

  cd "$new_path" || return 1
}

# Delete current worktree + branch
# -f: force delete
ha-del() {
  local force=false
  if [[ "$1" == "-f" ]]; then
    force=true
  fi

  _ha_is_worktree || { echo "Error: Not in a worktree" >&2; return 1; }

  local current_path="$(git rev-parse --show-toplevel)"
  local branch_name="$(git branch --show-current)"

  HA_BRANCH="$branch_name" _ha_exec_hook pre-del || return 1

  if [[ "$force" == false ]]; then
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "Error: Worktree has uncommitted changes or untracked files" >&2
      echo "Use 'ha del -f' to force delete" >&2
      return 1
    fi

    if ! git branch --merged "$(_ha_remote_head)" | grep -qE "^\*?\s*$branch_name$"; then
      echo "Error: Branch '$branch_name' is not merged into $(_ha_remote_head)" >&2
      echo "Use 'ha del -f' to force delete" >&2
      return 1
    fi
  fi

  cd "$(_ha_base_path)" || return 1

  if [[ "$force" == true ]]; then
    git worktree remove --force "$current_path" || return 1
    git branch -D "$branch_name" || return 1
  else
    git worktree remove "$current_path" || return 1
    git branch -d "$branch_name" || return 1
  fi
}

# Select worktree with fzf and cd
ha-cd() {
  local selected
  # Format: "branch<TAB>/path/to/worktree"
  # Extract branch from [...] or show "detached HEAD" for detached
  selected=$(git worktree list | awk '
    {
      path = $1
      if (match($0, /\[[^\]]+\]/)) {
        branch = substr($0, RSTART+1, RLENGTH-2)
      } else {
        branch = "detached HEAD (" $2 ")"
      }
      print branch "\t" path
    }
  ' | fzf --no-multi --exit-0 -d '\t' --with-nth=1 \
      --preview="git -C {2} log -15 --oneline --decorate")

  if [[ -n "$selected" ]]; then
    cd "$(echo "$selected" | cut -f2)" || return 1
  fi
}

# Go back to base directory
ha-home() {
  cd "$(_ha_base_path)" || return 1
}

# Checkout current commit to base directory
ha-use() {
  _ha_is_worktree || { echo "Error: Not in a worktree" >&2; return 1; }

  git -C "$(_ha_base_path)" -c advice.detachedHead=false switch --detach "$(git rev-parse HEAD)"
}

# Copy file/dir from base to current worktree
ha-copy() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "Usage: ha copy <path>" >&2
    return 1
  fi

  _ha_is_worktree || { echo "Error: Not in a worktree" >&2; return 1; }

  local base_path="$(_ha_base_path)"
  local current_path="$(git rev-parse --show-toplevel)"

  if [[ ! -e "$base_path/$target" ]]; then
    echo "Error: '$target' does not exist in base" >&2
    return 1
  fi

  if [[ -e "$current_path/$target" ]]; then
    echo "Error: '$target' already exists in current worktree" >&2
    return 1
  fi

  cp -r "$base_path/$target" "$current_path/$target"
}

# Symlink file/dir from base to current worktree
ha-link() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "Usage: ha link <path>" >&2
    return 1
  fi

  _ha_is_worktree || { echo "Error: Not in a worktree" >&2; return 1; }

  local base_path="$(_ha_base_path)"
  local current_path="$(git rev-parse --show-toplevel)"

  if [[ ! -e "$base_path/$target" ]]; then
    echo "Error: '$target' does not exist in base" >&2
    return 1
  fi

  if [[ -e "$current_path/$target" ]]; then
    echo "Error: '$target' already exists in current worktree" >&2
    return 1
  fi

  ln -s "$base_path/$target" "$current_path/$target"
}

# Delete all gone worktrees + branches
ha-gone() {
  _ha_fetch || return 1

  local gone_branches
  gone_branches=$(git branch -vv | cut -c3- | awk '/: gone]/{print $1}')

  if [[ -z "$gone_branches" ]]; then
    echo "No gone branches found"
    return 0
  fi

  echo "Gone branches:"
  echo "$gone_branches"
  echo ""

  local branch worktree_path
  while IFS= read -r branch; do
    # Resolve worktree path from branch name
    worktree_path=$(git worktree list | grep -F "[$branch]" | awk '{print $1}')

    if [[ -n "$worktree_path" ]]; then
      echo "Removing worktree: $worktree_path"
      git worktree remove "$worktree_path" || continue
    fi

    echo "Deleting branch: $branch"
    git branch -d "$branch"
  done <<< "$gone_branches"
}

# Run hook manually (in subshell)
ha-invoke() {
  local hook_name="$1"
  if [[ -z "$hook_name" ]]; then
    echo "Usage: ha invoke <hook>" >&2
    return 1
  fi

  local hook_file="$(_ha_base_path)/.ha/hooks/$hook_name"
  if [[ ! -f "$hook_file" ]]; then
    echo "Error: Hook '$hook_name' does not exist" >&2
    return 1
  fi

  ( source "$hook_file" )
}

# Completion
if [[ -n "$ZSH_VERSION" ]]; then
  _ha() {
    local -a commands
    commands=(
      'new:Create new worktree + branch'
      'get:Checkout remote branch as worktree'
      'extract:Extract current branch to worktree'
      'mv:Rename current worktree + branch'
      'del:Delete current worktree + branch'
      'cd:Select worktree with fzf'
      'home:Go back to base directory'
      'use:Checkout current commit to base'
      'gone:Delete all gone worktrees + branches'
      'ls:List worktrees'
      'copy:Copy file/dir from base'
      'link:Symlink file/dir from base'
      'invoke:Run hook manually'
    )
    _describe 'command' commands
  }
  # Register completion if compdef is available (may be deferred by plugin managers)
  (( $+functions[compdef] )) && compdef _ha ha
elif [[ -n "$BASH_VERSION" ]]; then
  _ha() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local commands="new get extract mv del cd home use gone ls copy link invoke"
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
  }
  complete -F _ha ha
fi
