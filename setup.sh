#!/usr/bin/env bash
# setup.sh: install Claude Code and copy the shared config into ~/.claude.
# Safe to re-run. It never overwrites a file that already exists in ~/.claude.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/dotclaude"
DEST="$HOME/.claude"
PROJECTS_ROOT="${CLAUDE_PROJECTS_ROOT:-$HOME/Claude}"

say() { printf '\n==> %s\n' "$1"; }

# 1. Claude Code ---------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  say "Claude Code already installed ($(claude --version 2>/dev/null || echo unknown version))"
else
  say "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# 2. Tools the skills use --------------------------------------------------------
for tool in git gh node; do
  if command -v "$tool" >/dev/null 2>&1; then
    say "$tool found"
  elif command -v brew >/dev/null 2>&1; then
    say "Installing $tool with Homebrew"
    brew install "$tool"
  else
    say "WARNING: $tool is missing and Homebrew isn't installed. Install $tool yourself (see README)."
  fi
done

# 3. Copy config without overwriting --------------------------------------------
say "Copying config into $DEST (existing files are kept)"
mkdir -p "$DEST"
copied=0; skipped=0
while IFS= read -r -d '' f; do
  rel="${f#"$SRC"/}"
  target="$DEST/$rel"
  if [ -e "$target" ]; then
    echo "  keep  $rel (already exists)"; skipped=$((skipped+1))
  else
    mkdir -p "$(dirname "$target")"
    cp -p "$f" "$target"
    echo "  add   $rel"; copied=$((copied+1))
  fi
done < <(find "$SRC" -type f -not -name '.DS_Store' -print0)
echo "  $copied added, $skipped kept"

chmod +x "$DEST"/skills/*/scripts/*.sh 2>/dev/null || true

# 4. Skill dependencies ------------------------------------------------------------
ROI="$DEST/skills/roi-executive-summary"
if [ -f "$ROI/package.json" ] && command -v npm >/dev/null 2>&1; then
  say "Installing roi-executive-summary dependencies"
  (cd "$ROI" && npm install --silent)
fi

# 5. Projects folder -----------------------------------------------------------------
mkdir -p "$PROJECTS_ROOT"
say "Projects folder ready at $PROJECTS_ROOT"

cat <<EOF

Done. Next:
  1. gh auth login            (sign in to GitHub with your own account)
  2. claude                   (sign in to Claude with your own account)
  3. Inside Claude Code, try: /new-project test-project
EOF
