# Portable development helpers for bash and zsh.
# Fish functions delegate to this file through bash; nothing runs on source.

_development-clean-repository() {
  local changes
  git rev-parse --show-toplevel >/dev/null 2>&1 || return 1
  changes=$(git status --porcelain) || return 1
  if [ -n "$changes" ]; then
    printf 'Commit or stash local changes first.\n' >&2
    return 1
  fi
  git symbolic-ref --quiet --short HEAD >/dev/null
}

_development-target() {
  if [ -z "${1:-}" ]; then
    printf 'A target branch is required.\n' >&2
    return 1
  fi
  git check-ref-format --branch "$1" >/dev/null
}

_development-confirm() {
  local confirmation
  if [ ! -t 0 ]; then
    printf 'Destructive operation requires an interactive terminal.\n' >&2
    return 1
  fi
  printf '%s\nType yes to continue: ' "$1" >&2
  IFS= read -r confirmation || return 1
  [ "$confirmation" = yes ]
}

flutter-update-pods() (
  command -v pod >/dev/null 2>&1 || return 1
  cd ios || return 1
  # Preserve the lockfile and the caller's working directory, even on failure.
  pod install --repo-update
)

create-release-branch() {
  _development-clean-repository || return 1
  if git show-ref --verify --quiet refs/heads/release; then
    _development-confirm 'Delete the existing local release branch and recreate it?' || return 1
    git branch -D release || return 1
  fi
  git switch -c release
}

create-release-and-push() {
  local remote_name="${1:-o}"
  checkout-to-branch-and-pull-changes develop "$remote_name" || return 1
  create-release-branch || return 1
  git push "$remote_name" release
}

create-release-branch-from-tag() {
  local tag_name="${1:-}"
  if [ -z "$tag_name" ]; then
    printf 'Usage: create-release-branch-from-tag <tag>\n' >&2
    return 1
  fi
  _development-clean-repository || return 1
  git rev-parse --verify "refs/tags/$tag_name^{commit}" >/dev/null || return 1
  if git show-ref --verify --quiet refs/heads/release; then
    _development-confirm 'Delete the existing local release branch and recreate it from the tag?' || return 1
    git branch -D release || return 1
  fi
  git switch -c release "refs/tags/$tag_name"
}

create-release-from-tag-and-push() {
  local remote_name="${1:-o}" tag_name="${2:-}"
  if [ -z "$tag_name" ]; then
    printf 'Usage: create-release-from-tag-and-push <remote> <tag>\n' >&2
    return 1
  fi
  git fetch "$remote_name" --tags || return 1
  create-release-branch-from-tag "$tag_name" || return 1
  git push "$remote_name" release
}

commit-with-friendly-message() {
  if [ "$#" -eq 0 ]; then
    printf 'Usage: commit-with-friendly-message <message> (staged files only)\n' >&2
    return 1
  fi
  git commit -m "$*"
}

commit-with-random-message() {
  local commit_message
  commit_message=$(curl --fail --silent --show-error --max-time 10 https://whatthecommit.com/index.txt) || return 1
  if [ -z "$commit_message" ]; then
    return 1
  fi
  git commit -m "$commit_message" -m 'This was generated'
}

reset-and-push-to-branch() {
  local current_branch target_branch="${1:-}" remote_name="${2:-o}" remote_commit
  _development-target "$target_branch" || return 1
  _development-clean-repository || return 1
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  if [ "$current_branch" = "$target_branch" ]; then
    printf 'Source and target must be different branches.\n' >&2
    return 1
  fi
  git fetch "$remote_name" "refs/heads/$target_branch" || return 1
  remote_commit=$(git rev-parse FETCH_HEAD) || return 1
  _development-confirm "Replace $target_branch with $current_branch locally and on $remote_name?" || return 1
  git switch "$target_branch" || return 1
  git reset --hard "$current_branch" || return 1
  git push "--force-with-lease=refs/heads/$target_branch:$remote_commit" "$remote_name" "HEAD:refs/heads/$target_branch" || return 1
  git switch "$current_branch"
}

checkout-to-branch-and-pull-changes() {
  local target_branch="${1:-}" remote_name="${2:-o}"
  _development-target "$target_branch" || return 1
  _development-clean-repository || return 1
  git switch "$target_branch" || return 1
  git pull --rebase "$remote_name" "$target_branch"
}

pull-branch() {
  local current_branch
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  checkout-to-branch-and-pull-changes "${1:-}" "${2:-o}" || return 1
  git switch "$current_branch"
}

merge-and-push-to-branch() {
  local current_branch target_branch="${1:-}" remote_name="${2:-o}"
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  _development-target "$target_branch" || return 1
  if [ "$current_branch" = "$target_branch" ]; then
    printf 'Source and target must be different branches.\n' >&2
    return 1
  fi
  checkout-to-branch-and-pull-changes "$target_branch" "$remote_name" || return 1
  git merge "$current_branch" || return 1
  git push "$remote_name" "$target_branch" || return 1
  git switch "$current_branch"
}

set-upstream-to-current-branch() {
  local current_branch remote_name="${1:-o}"
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  git branch --set-upstream-to="$remote_name/$current_branch" "$current_branch"
}

rebase-to-branch() {
  local current_branch target_branch="${1:-}" remote_name="${2:-o}"
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  _development-target "$target_branch" || return 1
  if [ "$current_branch" = "$target_branch" ]; then
    return 1
  fi
  checkout-to-branch-and-pull-changes "$target_branch" "$remote_name" || return 1
  git switch "$current_branch" || return 1
  git rebase -i "$target_branch"
}

delete-current-branch-from-local-and-go-to-branch() {
  local current_branch target_branch="${1:-}"
  _development-clean-repository || return 1
  _development-target "$target_branch" || return 1
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  if [ "$current_branch" = "$target_branch" ]; then
    return 1
  fi
  git switch "$target_branch" || return 1
  git branch -d "$current_branch"
}

rename-origin-to-o() {
  git remote rename origin o
}

clean-git-branches() {
  local current_branch branch_name
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  # Delete merged branches only. Git still refuses branches used by worktrees.
  git for-each-ref --merged=HEAD --format='%(refname:short)' refs/heads | while IFS= read -r branch_name; do
    case "$branch_name" in
      "$current_branch"|main|master|develop|dev|release|"${1:-dev}")
        continue
        ;;
    esac
    git branch -d "$branch_name" || return 1
  done
}

install-new-version-using-asdf() {
  if [ "$#" -ne 2 ]; then
    printf 'Usage: install-new-version-using-asdf <plugin> <version>\n' >&2
    return 1
  fi
  asdf install "$1" "$2"
}

make-version-global-using-asdf() {
  if [ "$#" -ne 2 ]; then
    printf 'Usage: make-version-global-using-asdf <plugin> <version>\n' >&2
    return 1
  fi
  if asdf set --help >/dev/null 2>&1; then
    asdf set -u "$1" "$2"
  else
    asdf global "$1" "$2"
  fi
}

install-new-version-and-make-global-using-asdf() {
  install-new-version-using-asdf "$@" || return 1
  make-version-global-using-asdf "$@"
}

vmrss() {
  local process_identifier="${1:-}"
  case "$process_identifier" in
    ''|*[!0-9]*)
      printf 'Usage: vmrss <numeric-pid>\n' >&2
      return 1
      ;;
  esac
  if [ ! -d /proc ]; then
    printf 'vmrss requires Linux /proc.\n' >&2
    return 1
  fi
  while [ -r "/proc/$process_identifier/status" ]; do
    grep '^VmRSS:' "/proc/$process_identifier/status" || return 1
    sleep 1
  done
}

integrate-to-branch() {
  local target_branch="${1:-dev-test}" remote_name="${2:-o}"
  local current_branch source_commit repository_name worktree_directory target_commit
  _development-target "$target_branch" || return 1
  _development-clean-repository || return 1
  current_branch=$(git symbolic-ref --short HEAD) || return 1
  source_commit=$(git rev-parse HEAD) || return 1
  if [ "$current_branch" = "$target_branch" ]; then
    return 1
  fi
  git fetch "$remote_name" || return 1
  if ! git show-ref --verify --quiet "refs/heads/$target_branch"; then
    if git show-ref --verify --quiet "refs/remotes/$remote_name/$target_branch"; then
      git branch "$target_branch" "$remote_name/$target_branch" || return 1
    else
      git branch "$target_branch" "$source_commit" || return 1
    fi
  fi
  repository_name=$(basename "$(git rev-parse --show-toplevel)") || return 1
  mkdir -p "$HOME/git-worktrees/$repository_name" || return 1
  worktree_directory="$HOME/git-worktrees/$repository_name/integration-$(date +%s)-$$"
  git worktree add "$worktree_directory" "$target_branch" || return 1
  if git show-ref --verify --quiet "refs/remotes/$remote_name/$target_branch"; then
    if ! git -C "$worktree_directory" merge --ff-only "$remote_name/$target_branch"; then
      printf 'Target diverged; worktree preserved at %s\n' "$worktree_directory" >&2
      return 1
    fi
  fi
  if ! git -C "$worktree_directory" merge --no-edit "$source_commit"; then
    printf 'Resolve conflicts in %s, commit, push, then remove the worktree.\n' "$worktree_directory" >&2
    return 1
  fi
  target_commit=$(git -C "$worktree_directory" rev-parse HEAD) || return 1
  if ! git -C "$worktree_directory" push "$remote_name" "HEAD:refs/heads/$target_branch"; then
    printf 'Push failed; worktree preserved at %s\n' "$worktree_directory" >&2
    return 1
  fi
  git worktree remove "$worktree_directory" || return 1
  printf 'Integrated %s into %s (%s).\n' "$current_branch" "$target_branch" "$target_commit"
}

check-repositories-with-pending-changes() (
  local root_directory repository_directory git_entry pending_count changes
  root_directory=$(cd "${1:-.}" && pwd -P) || return 1
  find "$root_directory" -name .git -prune -print0 | while IFS= read -r -d '' git_entry; do
    repository_directory=${git_entry%/.git}
    changes=$(git -C "$repository_directory" status --porcelain) || return 1
    if [ -n "$changes" ]; then
      printf 'Uncommitted changes: %s\n' "$repository_directory"
    fi
    if git -C "$repository_directory" rev-parse --verify '@{u}' >/dev/null 2>&1; then
      pending_count=$(git -C "$repository_directory" rev-list --count '@{u}..HEAD') || return 1
      if [ "$pending_count" -gt 0 ]; then
        printf '%s commit(s) pending push: %s\n' "$pending_count" "$repository_directory"
      fi
    fi
  done
)
