# Fish entrypoints share the bash implementation to avoid divergent Git logic.
# Installed alongside development.sh under ~/.config/development-helpers/.

set -l helper_directory (path dirname (status filename))
set -l helper_names \
    flutter-update-pods \
    create-release-branch \
    create-release-and-push \
    create-release-branch-from-tag \
    create-release-from-tag-and-push \
    commit-with-friendly-message \
    commit-with-random-message \
    reset-and-push-to-branch \
    pull-branch \
    merge-and-push-to-branch \
    set-upstream-to-current-branch \
    rebase-to-branch \
    checkout-to-branch-and-pull-changes \
    delete-current-branch-from-local-and-go-to-branch \
    rename-origin-to-o \
    clean-git-branches \
    install-new-version-using-asdf \
    make-version-global-using-asdf \
    install-new-version-and-make-global-using-asdf \
    vmrss \
    integrate-to-branch \
    check-repositories-with-pending-changes

for helper_name in $helper_names
    function $helper_name --inherit-variable helper_name --inherit-variable helper_directory
        command bash -c 'source "$1/development.sh"; shift; "$@"' development-helpers "$helper_directory" "$helper_name" $argv
    end
end
