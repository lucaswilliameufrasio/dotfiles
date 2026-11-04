"""Exercise development helpers using isolated local Git repositories."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import unittest
import uuid


SHELL_DIRECTORY = Path(__file__).resolve().parents[1]
HELPER_NAMES = [
    "flutter-update-pods",
    "create-release-branch",
    "create-release-and-push",
    "create-release-branch-from-tag",
    "create-release-from-tag-and-push",
    "commit-with-friendly-message",
    "commit-with-random-message",
    "reset-and-push-to-branch",
    "pull-branch",
    "merge-and-push-to-branch",
    "set-upstream-to-current-branch",
    "rebase-to-branch",
    "checkout-to-branch-and-pull-changes",
    "delete-current-branch-from-local-and-go-to-branch",
    "rename-origin-to-o",
    "clean-git-branches",
    "install-new-version-using-asdf",
    "make-version-global-using-asdf",
    "install-new-version-and-make-global-using-asdf",
    "vmrss",
    "integrate-to-branch",
    "check-repositories-with-pending-changes",
]


class HelperTests(unittest.TestCase):
    def setUp(self):
        self.directory = (
            Path.home() / "git-worktrees" / "dotfiles-tests" / uuid.uuid4().hex
        )
        self.directory.mkdir(parents=True)
        self.addCleanup(shutil.rmtree, self.directory)
        self.home = self.directory / "home"
        self.home.mkdir()
        self.repository = self.directory / "repository with spaces"
        self.repository.mkdir()
        self.environment = os.environ.copy()
        self.environment.update(
            HOME=str(self.home),
            GIT_CONFIG_NOSYSTEM="1",
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_AUTHOR_NAME="Test Author",
            GIT_AUTHOR_EMAIL="author@example.invalid",
            GIT_COMMITTER_NAME="Test Author",
            GIT_COMMITTER_EMAIL="author@example.invalid",
            GIT_TERMINAL_PROMPT="0",
        )
        for variable in list(self.environment):
            if variable.startswith("GIT_") and variable not in {
                "GIT_CONFIG_NOSYSTEM",
                "GIT_CONFIG_GLOBAL",
                "GIT_AUTHOR_NAME",
                "GIT_AUTHOR_EMAIL",
                "GIT_COMMITTER_NAME",
                "GIT_COMMITTER_EMAIL",
                "GIT_TERMINAL_PROMPT",
            }:
                del self.environment[variable]
        self.git("init", "-b", "main")
        (self.repository / "initial.txt").write_text("initial\n")
        self.git("add", "initial.txt")
        self.git("commit", "-m", "Initial commit")

    def run_command(self, command, check=True, directory=None):
        return subprocess.run(
            command,
            cwd=directory or self.repository,
            env=self.environment,
            stdin=subprocess.DEVNULL,
            text=True,
            capture_output=True,
            check=check,
            timeout=30,
        )

    def git(self, *arguments, check=True):
        return self.run_command(["git", *arguments], check=check)

    def helper(self, code, shell="bash", check=True):
        extension = "fish" if shell == "fish" else "sh"
        source_file = shlex.quote(str(SHELL_DIRECTORY / f"development.{extension}"))
        options = {"bash": ["--noprofile", "--norc"], "zsh": ["-f"], "fish": ["--no-config"]}
        return self.run_command(
            [shell, *options[shell], "-c", f"source {source_file}\n{code}"],
            check=check,
        )

    def add_remote(self):
        remote_directory = self.directory / "remote.git"
        self.run_command(["git", "init", "--bare", str(remote_directory)])
        self.git("remote", "add", "origin", str(remote_directory))
        self.git("push", "-u", "origin", "main")
        return remote_directory

    def test_should_load_every_helper_without_changing_repository(self):
        for shell in ("bash", "zsh", "fish"):
            if not shutil.which(shell):
                continue
            with self.subTest(shell=shell):
                if shell == "bash":
                    code = "\n".join(f"declare -F {name}" for name in HELPER_NAMES)
                elif shell == "zsh":
                    code = "\n".join(f"whence -w {name}" for name in HELPER_NAMES)
                else:
                    code = "functions -q " + " ".join(HELPER_NAMES)
                self.helper(code, shell=shell)
                self.assertEqual(self.git("status", "--porcelain").stdout, "")
                self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")

    def test_should_refuse_missing_target_without_switching(self):
        self.assertNotEqual(self.helper("pull-branch", check=False).returncode, 0)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")

    def test_should_refuse_dirty_tree(self):
        self.git("branch", "develop")
        (self.repository / "untracked.txt").write_text("preserve me")
        result = self.helper("checkout-to-branch-and-pull-changes develop", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")

    def test_should_use_explicit_remote_for_upstream(self):
        self.add_remote()
        for shell in ("bash", "zsh", "fish"):
            if shutil.which(shell):
                self.helper("set-upstream-to-current-branch origin", shell=shell)
                upstream = self.git("rev-parse", "--abbrev-ref", "@{u}").stdout.strip()
                self.assertEqual(upstream, "origin/main")

    def test_should_update_branch_and_return_after_success(self):
        self.add_remote()
        self.git("branch", "develop")
        self.git("push", "origin", "develop")
        for shell in ("bash", "zsh", "fish"):
            if shutil.which(shell):
                self.helper("pull-branch develop origin", shell=shell)
                self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")

    def test_should_preserve_existing_release_without_interactive_confirmation(self):
        self.git("branch", "release")
        original_commit = self.git("rev-parse", "release").stdout
        self.assertNotEqual(self.helper("create-release-branch", check=False).returncode, 0)
        self.assertEqual(self.git("rev-parse", "release").stdout, original_commit)

    def test_should_create_release_from_validated_tag(self):
        self.git("tag", "v1.2.3")
        original_commit = self.git("rev-parse", "HEAD").stdout
        self.helper("create-release-branch-from-tag v1.2.3")
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "release")
        self.assertEqual(self.git("rev-parse", "HEAD").stdout, original_commit)

    def test_should_not_delete_release_when_tag_is_missing(self):
        self.git("branch", "release")
        result = self.helper("create-release-branch-from-tag missing-tag", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.git("rev-parse", "--verify", "release")

    def test_should_stop_on_fetch_failure(self):
        self.git("tag", "v1.2.3")
        result = self.helper("create-release-from-tag-and-push missing v1.2.3", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(self.git("show-ref", "--verify", "refs/heads/release", check=False).returncode, 0)

    def test_should_refuse_reset_without_confirmation(self):
        self.add_remote()
        self.git("branch", "destination")
        self.git("push", "origin", "destination")
        original_commit = self.git("rev-parse", "destination").stdout
        result = self.helper("reset-and-push-to-branch destination origin", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("rev-parse", "destination").stdout, original_commit)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")

    def test_should_preserve_unmerged_branches_during_cleanup(self):
        self.git("switch", "-c", "unmerged")
        (self.repository / "feature.txt").write_text("feature")
        self.git("add", "feature.txt")
        self.git("commit", "-m", "Feature")
        self.git("switch", "main")
        self.git("branch", "merged")
        self.git("branch", "release")
        self.helper("clean-git-branches")
        self.git("show-ref", "--verify", "refs/heads/unmerged")
        self.git("show-ref", "--verify", "refs/heads/release")
        self.assertNotEqual(self.git("show-ref", "--verify", "refs/heads/merged", check=False).returncode, 0)

    def test_should_commit_only_staged_files_and_preserve_message(self):
        for shell in ("bash", "zsh", "fish"):
            if shutil.which(shell):
                (self.repository / f"staged-{shell}.txt").write_text("staged")
                (self.repository / "private-untracked.txt").write_text("not staged")
                self.git("add", f"staged-{shell}.txt")
                self.helper("commit-with-friendly-message 'feat: message with spaces'", shell=shell)
                self.assertEqual(self.git("log", "-1", "--format=%s").stdout.strip(), "feat: message with spaces")
                self.assertIn("?? private-untracked.txt", self.git("status", "--porcelain").stdout)

    def test_should_report_worktrees_and_preserve_directory(self):
        worktree_directory = self.directory / "linked worktree"
        self.git("worktree", "add", "-b", "linked", str(worktree_directory))
        (worktree_directory / "pending.txt").write_text("pending")
        result = self.helper(f"check-repositories-with-pending-changes {shlex.quote(str(self.directory))}\npwd")
        self.assertIn(str(worktree_directory), result.stdout)
        self.assertEqual(result.stdout.splitlines()[-1], str(self.repository))

    def test_should_integrate_and_push_without_changing_current_branch(self):
        remote_directory = self.add_remote()
        self.git("push", "origin", "main:dev-test")
        self.git("switch", "-c", "feature")
        (self.repository / "feature.txt").write_text("feature")
        self.git("add", "feature.txt")
        self.git("commit", "-m", "Feature")
        source_commit = self.git("rev-parse", "HEAD").stdout.strip()
        self.helper("integrate-to-branch dev-test origin")
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "feature")
        result = self.run_command(["git", "--git-dir", str(remote_directory), "rev-parse", "dev-test"])
        self.assertEqual(result.stdout.strip(), source_commit)
        self.assertEqual(len(self.git("worktree", "list", "--porcelain").stdout.split("worktree ")) - 1, 1)

    def test_should_rebase_stale_target_before_integrating(self):
        remote_directory = self.add_remote()
        self.git("branch", "dev-test")
        self.git("switch", "-c", "remote-only")
        (self.repository / "remote-only.txt").write_text("remote\n")
        self.git("add", "remote-only.txt")
        self.git("commit", "-m", "Remote only")
        self.git("push", "origin", "HEAD:dev-test")
        self.git("switch", "-c", "feature")
        (self.repository / "feature.txt").write_text("feature\n")
        self.git("add", "feature.txt")
        self.git("commit", "-m", "Feature")
        source_commit = self.git("rev-parse", "HEAD").stdout.strip()
        self.helper("integrate-to-branch dev-test origin")
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "feature")
        result = self.run_command(["git", "--git-dir", str(remote_directory), "rev-parse", "dev-test"])
        self.assertEqual(result.stdout.strip(), source_commit)
        self.assertEqual(self.git("rev-parse", "dev-test").stdout.strip(), source_commit)

    def test_should_rebase_diverged_target_and_keep_both_changes(self):
        remote_directory = self.add_remote()
        self.git("switch", "-c", "dev-test")
        (self.repository / "local-only.txt").write_text("local\n")
        self.git("add", "local-only.txt")
        self.git("commit", "-m", "Local only")
        self.git("switch", "main")
        (self.repository / "remote-only.txt").write_text("remote\n")
        self.git("add", "remote-only.txt")
        self.git("commit", "-m", "Remote only")
        self.git("push", "origin", "HEAD:dev-test")
        self.git("switch", "-c", "feature")
        (self.repository / "feature.txt").write_text("feature\n")
        self.git("add", "feature.txt")
        self.git("commit", "-m", "Feature")
        source_commit = self.git("rev-parse", "HEAD").stdout.strip()
        self.helper("integrate-to-branch dev-test origin")
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "feature")
        remote_commit = self.run_command(
            ["git", "--git-dir", str(remote_directory), "rev-parse", "dev-test"]
        ).stdout.strip()
        self.assertEqual(self.git("merge-base", "--is-ancestor", source_commit, remote_commit).returncode, 0)
        self.assertEqual(self.git("show", f"{remote_commit}:local-only.txt").stdout, "local\n")
        self.assertEqual(self.git("show", f"{remote_commit}:remote-only.txt").stdout, "remote\n")
        self.assertEqual(self.git("show", f"{remote_commit}:feature.txt").stdout, "feature\n")

    def test_should_preserve_lockfile_and_directory_when_pods_fail(self):
        ios_directory = self.repository / "ios"
        ios_directory.mkdir()
        lockfile = ios_directory / "Podfile.lock"
        lockfile.write_text("locked versions")
        binary_directory = self.directory / "bin"
        binary_directory.mkdir()
        pod = binary_directory / "pod"
        pod.write_text("#!/bin/sh\nexit 42\n")
        pod.chmod(0o700)
        self.environment["PATH"] = str(binary_directory) + os.pathsep + self.environment["PATH"]
        for shell in ("bash", "zsh", "fish"):
            if shutil.which(shell):
                result = self.helper("flutter-update-pods", shell=shell, check=False)
                self.assertEqual(result.returncode, 42)
                self.assertEqual(lockfile.read_text(), "locked versions")

    def test_should_reject_invalid_process_identifier(self):
        self.assertNotEqual(self.helper("vmrss ../status", check=False).returncode, 0)

    def test_should_install_idempotently_and_preserve_startup(self):
        for shell, relative_file in (("zsh", ".zshrc"), ("fish", ".config/fish/config.fish")):
            with self.subTest(shell=shell):
                startup_file = self.home / relative_file
                startup_file.parent.mkdir(parents=True, exist_ok=True)
                original = "# User configuration must remain unchanged\n"
                startup_file.write_text(original)
                command = ["bash", str(SHELL_DIRECTORY / "install.sh"), shell]
                self.run_command(command)
                first_content = startup_file.read_text()
                self.run_command(command)
                self.assertTrue(first_content.startswith(original))
                self.assertEqual(startup_file.read_text(), first_content)
                backups = list((self.home / ".config/development-helpers/backups").glob("*/startup"))
                self.assertTrue(any(backup.read_text() == original for backup in backups))


if __name__ == "__main__":
    unittest.main()
