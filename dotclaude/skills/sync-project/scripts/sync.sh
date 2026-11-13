#!/usr/bin/env bash
# sync.sh [commit message] [project-dir]
# Commit all local changes, pull --rebase, push, and report. Prints KEY=VALUE lines.
set -uo pipefail
MSG="${1:-}"
DIR="${2:-$PWD}"
cd "$DIR" || { echo "ERROR=no such directory: $DIR"; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR=$DIR is not a git repository"; exit 2; }
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
ME="$(gh api user --jq .login 2>/dev/null || git config user.name)"
echo "DIR=$ROOT"; echo "GH_USER=$ME"

# Stamp STATUS.md so readers know how fresh it is.
if [ -f STATUS.md ] && grep -q '^_Last updated' STATUS.md; then
  sed -i '' "s/^_Last updated .* by [^.]*\./_Last updated $(date +%Y-%m-%d) by $ME./" STATUS.md
fi

grep -qx '.DS_Store' .gitignore 2>/dev/null || echo '.DS_Store' >> .gitignore
git add -A
if git diff --cached --quiet; then
  echo "COMMITTED=no"
else
  [ -n "$MSG" ] || MSG="Work in progress ($ME, $(date '+%Y-%m-%d %H:%M'))"
  if git commit -q -m "$MSG"; then echo "COMMITTED=yes"; echo "COMMIT=$(git log -1 --format='%h %s')"; else echo "ERROR=commit failed"; exit 1; fi
fi

BRANCH="$(git symbolic-ref --short -q HEAD || echo main)"; echo "BRANCH=$BRANCH"

if ! git remote get-url origin >/dev/null 2>&1; then echo "WARN=no origin remote; nothing pulled or pushed"; exit 0; fi

BEFORE="$(git rev-parse HEAD)"
git fetch -q origin || { echo "ERROR=fetch failed"; exit 1; }
if git rev-parse --verify -q "origin/$BRANCH" >/dev/null; then
  if git pull -q --rebase origin "$BRANCH"; then
    echo "PULLED=yes"
    echo "INCOMING_COMMITS<<END"; git log --format='%h %an %ar %s' "$BEFORE..HEAD" --no-merges 2>/dev/null | head -20; echo "END"
  else
    echo "ERROR=rebase conflict. Resolve, then: git add <files> && git rebase --continue && git push"
    echo "CONFLICTS<<END"; git diff --name-only --diff-filter=U; echo "END"
    exit 1
  fi
else
  echo "PULLED=no (no remote branch yet)"
fi

if git push -q -u origin "$BRANCH" 2>/tmp/sync_push_err.$$; then
  echo "PUSHED=yes"
else
  echo "ERROR=push failed: $(tr '\n' ' ' < /tmp/sync_push_err.$$)"; rm -f /tmp/sync_push_err.$$; exit 1
fi
rm -f /tmp/sync_push_err.$$
echo "AHEAD_BEHIND=$(git rev-list --left-right --count "HEAD...origin/$BRANCH" 2>/dev/null | tr '\t' '/')"
