#!/usr/bin/env bash
# project_status.sh [project-name]
# With no name: lists candidate projects under ~/Claude. With a name: pulls (if clean) and
# prints where the project stands. KEY=VALUE output for Claude to read.
set -uo pipefail
ROOT="${CLAUDE_PROJECTS_ROOT:-$HOME/Claude}"
NAME="${1:-}"

list_projects() {
  echo "PROJECTS<<END"
  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    if [ -d "$d/.git" ]; then
      last="$(git -C "$d" log -1 --format='%ar: %s' 2>/dev/null)"
      dirty="$([ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && echo ' [uncommitted changes]')"
      remote="$(git -C "$d" remote get-url origin 2>/dev/null | sed -E 's#.*github.com[/:]##; s#\.git$##')"
      echo "$n	${remote:-no remote}	${last:-no commits}$dirty"
    else
      echo "$n	not a git repo	$(ls -A "$d" | grep -v '^\.DS_Store$' | wc -l | tr -d ' ') files"
    fi
  done
  echo "END"
}

if [ -z "$NAME" ]; then list_projects; exit 0; fi
DIR="$ROOT/$NAME"
if [ ! -d "$DIR" ]; then
  echo "ERROR=no folder $DIR. Use /new-project $NAME to create it, or pick one of these:"
  list_projects; exit 2
fi
echo "DIR=$DIR"
ME="$(gh api user --jq .login 2>/dev/null || echo unknown)"; echo "GH_USER=$ME"

if [ ! -d "$DIR/.git" ]; then
  echo "GIT=no"; echo "TOP_LEVEL<<END"; ls -A "$DIR" | grep -v '^\.DS_Store$' | head -40; echo "END"
  echo "WARN=not a git repository; /new-project $NAME would create or attach a GitHub repo"
  exit 0
fi
echo "GIT=yes"
cd "$DIR"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"; echo "BRANCH=$BRANCH"
REMOTE="$(git remote get-url origin 2>/dev/null || true)"; echo "REMOTE=${REMOTE:-none}"
FULL="$(echo "$REMOTE" | sed -E 's#.*github.com[/:]##; s#\.git$##')"
DIRTY="$(git status --porcelain)"
if [ -n "$DIRTY" ]; then echo "UNCOMMITTED<<END"; echo "$DIRTY" | head -30; echo "END"; else echo "UNCOMMITTED=none"; fi

if [ -n "$REMOTE" ]; then
  BEFORE="$(git rev-parse HEAD)"
  if git fetch -q origin 2>/dev/null; then
    AB="$(git rev-list --left-right --count "HEAD...origin/$BRANCH" 2>/dev/null | tr '\t' '/')"
    echo "AHEAD_BEHIND=${AB:-?}"
    BEHIND="${AB#*/}"
    if [ -z "$DIRTY" ] && [ "${BEHIND:-0}" != "0" ] && [ "${BEHIND:-0}" != "?" ]; then
      if git pull -q --ff-only origin "$BRANCH" 2>/dev/null; then
        echo "PULLED=yes"
        echo "INCOMING_COMMITS<<END"; git log --format='%h %an %ar %s' "$BEFORE..HEAD" | head -20; echo "END"
        echo "INCOMING_FILES<<END"; git diff --stat "$BEFORE..HEAD" | tail -15; echo "END"
      else
        echo "PULLED=no"; echo "WARN=branch diverged from origin/$BRANCH; needs a rebase or merge (run /sync-project)"
      fi
    elif [ -n "$DIRTY" ] && [ "${BEHIND:-0}" != "0" ]; then
      echo "PULLED=no"; echo "WARN=remote has new commits but local changes are uncommitted; run /sync-project to commit, rebase and push"
    else
      echo "PULLED=no (up to date)"
    fi
  else
    echo "WARN=fetch failed (offline or no access)"
  fi
  if [ -n "$FULL" ] && command -v gh >/dev/null; then
    COLLABS="$(gh api "repos/$FULL/collaborators?per_page=100" --jq '.[].login' 2>/dev/null | grep -vx "$ME" | tr '\n' ' ')"
    [ -z "$COLLABS" ] && COLLABS="$(gh api "repos/$FULL/contributors?per_page=100" --jq '.[].login' 2>/dev/null | grep -vx "$ME" | tr '\n' ' ')"
    echo "COLLABORATORS=${COLLABS:-none}"
    echo "OPEN_ISSUES<<END"; gh issue list -R "$FULL" --limit 10 2>/dev/null; echo "END"
    echo "OPEN_PRS<<END"; gh pr list -R "$FULL" --limit 10 2>/dev/null; echo "END"
  fi
fi

echo "RECENT_COMMITS<<END"; git log --format='%h %an %ar %s' -10; echo "END"
echo "COMMITS_BY_OTHERS_LAST_14D<<END"; git log --since='14 days ago' --format='%h %an %ar %s' | grep -v " $ME " | head -15; echo "END"
for f in CLAUDE.md STATUS.md README.md; do [ -f "$f" ] && echo "HAS_$(echo "$f" | sed 's/\.md$//' | tr a-z A-Z)=yes" || echo "HAS_$(echo "$f" | sed 's/\.md$//' | tr a-z A-Z)=no"; done
echo "RECENTLY_CHANGED_FILES<<END"; git log --name-only --format='' -15 | grep -v '^$' | awk '!s[$0]++' | head -20; echo "END"
