#!/usr/bin/env bash
# setup_project.sh <project-name>
# Ensures ~/Claude/<name> exists, finds or creates the GitHub repo <name> for the
# logged-in gh user, syncs the two, and prints a KEY=VALUE summary for Claude to read.
set -uo pipefail

NAME="${1:-}"
if [ -z "$NAME" ]; then echo "ERROR=usage: setup_project.sh <project-name>"; exit 2; fi
if ! [[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "ERROR=project name must be letters, digits, dots, dashes or underscores (GitHub repo rules): '$NAME'"; exit 2
fi

ROOT="${CLAUDE_PROJECTS_ROOT:-$HOME/Claude}"
DIR="$ROOT/$NAME"

command -v gh >/dev/null || { echo "ERROR=gh CLI not installed (brew install gh)"; exit 2; }
if ! gh auth status >/dev/null 2>&1; then echo "ERROR=gh is not logged in; run: gh auth login"; exit 2; fi
ME="$(gh api user --jq .login 2>/dev/null)"
[ -n "$ME" ] || { echo "ERROR=could not read GitHub login from gh api user"; exit 2; }

echo "GH_USER=$ME"
echo "DIR=$DIR"

# ---- 1. local directory -----------------------------------------------------
if [ -d "$DIR" ]; then
  echo "DIR_STATE=existing"
else
  mkdir -p "$DIR" && echo "DIR_STATE=created"
fi

# ---- 2. does a repo with this name exist that $ME can reach? ----------------
MATCHES="$(gh api "user/repos?affiliation=owner,collaborator,organization_member&per_page=100" --paginate \
  --jq ".[] | select(.name == \"$NAME\") | .full_name" 2>/dev/null)"
FULL=""
if [ -n "$MATCHES" ]; then
  if echo "$MATCHES" | grep -qx "$ME/$NAME"; then FULL="$ME/$NAME"; else FULL="$(echo "$MATCHES" | head -1)"; fi
  COUNT="$(echo "$MATCHES" | wc -l | tr -d ' ')"
  [ "$COUNT" -gt 1 ] && echo "REPO_OTHER_MATCHES=$(echo "$MATCHES" | grep -vx "$FULL" | tr '\n' ' ')"
fi

ensure_gitignore() {
  touch "$DIR/.gitignore"
  grep -qx '.DS_Store' "$DIR/.gitignore" || echo '.DS_Store' >> "$DIR/.gitignore"
}

# ---- 3. create or sync -------------------------------------------------------
if [ -z "$FULL" ]; then
  # No repo anywhere -> create a private one under $ME and push the local dir to it.
  if [ ! -d "$DIR/.git" ]; then git -C "$DIR" init -q -b main; fi
  ensure_gitignore
  [ -f "$DIR/README.md" ] || printf '# %s\n\nCreated %s by %s.\n' "$NAME" "$(date +%Y-%m-%d)" "$ME" > "$DIR/README.md"
  git -C "$DIR" add -A
  if ! git -C "$DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "$DIR" commit -q -m "Initial commit" || true
  elif ! git -C "$DIR" diff --cached --quiet; then
    git -C "$DIR" commit -q -m "Add project scaffolding" || true
  fi
  if git -C "$DIR" remote get-url origin >/dev/null 2>&1; then
    echo "WARN=local repo already had an 'origin' remote: $(git -C "$DIR" remote get-url origin); not creating a GitHub repo"
    echo "REPO_STATE=local-remote-unknown"
  else
    if gh repo create "$ME/$NAME" --private --source="$DIR" --remote=origin --push >/dev/null 2>&1; then
      FULL="$ME/$NAME"; echo "REPO_STATE=created"
    else
      echo "ERROR=gh repo create failed for $ME/$NAME"; echo "REPO_STATE=failed"
    fi
  fi
else
  DEFAULT="$(gh api "repos/$FULL" --jq .default_branch 2>/dev/null || echo main)"
  URL="https://github.com/$FULL.git"
  if [ -d "$DIR/.git" ]; then
    ORIGIN="$(git -C "$DIR" remote get-url origin 2>/dev/null || true)"
    if [ -z "$ORIGIN" ]; then git -C "$DIR" remote add origin "$URL"; fi
    if git -C "$DIR" fetch -q origin 2>/dev/null; then
      if [ -n "$(git -C "$DIR" status --porcelain)" ]; then
        echo "WARN=local changes present; skipped pull (run /sync-project to commit, pull and push)"
        echo "REPO_STATE=fetched-dirty"
      elif git -C "$DIR" pull -q --ff-only origin "$DEFAULT" 2>/dev/null; then
        echo "REPO_STATE=pulled"
      else
        echo "WARN=local branch has diverged from origin/$DEFAULT; pull --ff-only refused. Inspect with: git -C $DIR status; git -C $DIR log --oneline --left-right HEAD...origin/$DEFAULT"
        echo "REPO_STATE=diverged"
      fi
    else
      echo "WARN=could not fetch from $URL"; echo "REPO_STATE=fetch-failed"
    fi
  elif [ -z "$(ls -A "$DIR" 2>/dev/null | grep -v '^\.DS_Store$')" ]; then
    if gh repo clone "$FULL" "$DIR" -- -q 2>/dev/null; then echo "REPO_STATE=cloned"; else echo "ERROR=clone of $FULL failed"; echo "REPO_STATE=failed"; fi
  else
    # Non-empty folder that is not a git repo: attach it to the remote without losing local files.
    git -C "$DIR" init -q -b "$DEFAULT"
    git -C "$DIR" remote add origin "$URL"
    git -C "$DIR" fetch -q origin
    if git -C "$DIR" checkout -q -b "$DEFAULT" --track "origin/$DEFAULT" 2>/tmp/setup_project_err.$$ ; then
      echo "REPO_STATE=attached-to-existing-folder"
    elif git -C "$DIR" reset -q "origin/$DEFAULT" 2>/dev/null && git -C "$DIR" branch -q --set-upstream-to="origin/$DEFAULT" "$DEFAULT" 2>/dev/null; then
      # HEAD now points at the remote branch; local files stay as they were and show as modifications.
      echo "WARN=folder already had files that overlap the repo; HEAD set to origin/$DEFAULT without touching them. Review 'git status' before syncing"
      echo "REPO_STATE=attached-with-overlap"
    else
      echo "ERROR=could not attach $DIR to $FULL: $(cat /tmp/setup_project_err.$$)"; echo "REPO_STATE=failed"
    fi
    rm -f /tmp/setup_project_err.$$
  fi
  ensure_gitignore
fi

# ---- 4. repo facts and collaborators ----------------------------------------
if [ -n "$FULL" ]; then
  echo "REPO=$FULL"
  echo "REPO_URL=https://github.com/$FULL"
  echo "REPO_PRIVATE=$(gh api "repos/$FULL" --jq .private 2>/dev/null)"
  echo "DEFAULT_BRANCH=$(gh api "repos/$FULL" --jq .default_branch 2>/dev/null)"
  OWNER="${FULL%%/*}"
  [ "$OWNER" != "$ME" ] && echo "REPO_OWNED_BY_OTHER=$OWNER"
  COLLABS="$(gh api "repos/$FULL/collaborators?per_page=100" --jq '.[].login' 2>/dev/null | grep -vx "$ME" | tr '\n' ' ')"
  if [ -z "$COLLABS" ]; then
    # Without push rights the collaborators endpoint is forbidden; fall back to commit authors.
    COLLABS="$(gh api "repos/$FULL/contributors?per_page=100" --jq '.[].login' 2>/dev/null | grep -vx "$ME" | tr '\n' ' ')"
  fi
  echo "COLLABORATORS=${COLLABS:-none}"
  echo "OPEN_ISSUES=$(gh api "repos/$FULL" --jq .open_issues_count 2>/dev/null)"
  echo "OPEN_PRS=$(gh pr list -R "$FULL" --json number --jq 'length' 2>/dev/null || echo 0)"
fi

# ---- 5. what is in the folder ----------------------------------------------
for f in CLAUDE.md STATUS.md README.md; do
  [ -f "$DIR/$f" ] && echo "HAS_$(echo "$f" | tr '.a-z' '_A-Z' | sed 's/_MD$//')=yes" || echo "HAS_$(echo "$f" | tr '.a-z' '_A-Z' | sed 's/_MD$//')=no"
done
if [ -d "$DIR/.git" ]; then
  echo "RECENT_COMMITS<<END"; git -C "$DIR" log --format='%h %an %ar %s' -8 2>/dev/null; echo "END"
fi
echo "TOP_LEVEL<<END"; ls -A "$DIR" | grep -v '^\.DS_Store$' | head -40; echo "END"
