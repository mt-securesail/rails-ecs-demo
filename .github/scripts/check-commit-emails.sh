#!/usr/bin/env bash
# Regression guard for finding #17 (personal email in public commit metadata).
#
# Usage: check-commit-emails.sh <base-sha> <head-sha>
#
# Checks every commit in base..head: the author, the committer, and every
# email address in the commit message (such as Co-authored-by lines) must be
# a no-reply address. Fails if any isn't.
#
# This repo's Actions logs are public, so a failing address is never printed;
# only the commit ID and which field failed. Run `git log --format=full <sha>`
# locally to see it.
set -euo pipefail

base="$1"
head="$2"

# GitHub no-reply addresses, GitHub's own web-commit address, and the
# Co-authored-by address Claude Code adds.
allowed='(@users\.noreply\.github\.com|^noreply@github\.com|^noreply@anthropic\.com)$'

failures=0
commits=0

check() { # sha, field, email
  if ! printf '%s\n' "$3" | grep -qiE "$allowed"; then
    echo "::error::Commit ${1:0:12}: $2 email is not a no-reply address (not shown: this log is public)"
    failures=$((failures + 1))
  fi
}

# A separate assignment so a bad range fails the job instead of checking nothing.
shas=$(git rev-list "$base..$head")

for sha in $shas; do
  commits=$((commits + 1))
  check "$sha" "author" "$(git log -1 --format='%ae' "$sha")"
  check "$sha" "committer" "$(git log -1 --format='%ce' "$sha")"
  # Any address in the message counts (Co-authored-by lines and anything else),
  # since GitHub shows the whole message publicly.
  while IFS= read -r email; do
    [ -z "$email" ] && continue
    check "$sha" "commit message (e.g. Co-authored-by)" "$email"
  done < <(git log -1 --format='%B' "$sha" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' || true)
done

echo "Checked $commits commit(s); $failures problem(s)."
if [ "$failures" -gt 0 ]; then
  echo "Fix: set 'git config user.email' to your GitHub no-reply address, then rewrite the PR's commits (for example 'git rebase -i' with 'git commit --amend --reset-author'), and force-push the PR branch."
  exit 1
fi
