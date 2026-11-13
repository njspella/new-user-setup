---
name: sync-project
description: >-
  Checkpoint the current project for collaborators: update STATUS.md (now / done / next /
  blockers), commit everything, pull with rebase, push to GitHub, and report what came in from
  other people. Use `/sync-project [message]` whenever a piece of work is finished, before
  switching projects, at the end of a session, or when the user says "push", "save my work",
  "sync", "commit this", "checkpoint", or "let <collaborator> see this". Also use it unprompted
  at natural checkpoints in any ~/Claude project whose CLAUDE.md has a collaboration section,
  because unsynced work is invisible to collaborators.
---

# Sync Project

Shared repositories only work when everyone pushes often and leaves a readable trail. This
skill makes a checkpoint cheap: status first, then commit, pull, push, report.

## 1. Update STATUS.md before committing

The commit is the mechanism; `STATUS.md` is the message to the humans. Before running the
script, edit it so it is true right now:

- **Now:** what is in progress (and who, by GitHub login).
- **Done recently:** what this session finished, dated.
- **Next:** the one to three concrete next steps, so a collaborator or `/continue-project` can
  continue without re-deriving the plan.
- **Blockers / questions:** anything waiting on someone.

If there is no STATUS.md, create one from
`~/.claude/skills/new-project/assets/STATUS.md.template`. Keep entries short and specific;
"resume rewrite v3 drafted, waiting on a collaborator's review" beats "worked on resume".

## 2. Run the sync script

```bash
bash ~/.claude/skills/sync-project/scripts/sync.sh "<commit message>" [project-dir]
```

Write the commit message yourself: imperative, says what changed and for whom it matters.
The script stamps STATUS.md's "Last updated" line, adds `.DS_Store` to `.gitignore`, commits
everything, pulls with rebase, pushes, and prints `KEY=VALUE` lines plus `INCOMING_COMMITS`
(what other people pushed since the last sync).

Do not commit secrets or large generated binaries. If `git status` shows something that should
not be in the repo (API keys, `.env`, multi-megabyte exports), add it to `.gitignore` first.

## 3. Handle the result

- **Conflict** (`ERROR=rebase conflict`, `CONFLICTS` list): resolve each file keeping both
  sides' intent, then `git add` them, `git rebase --continue`, and `git push`. Tell the user which
  files conflicted and how you resolved them; if the two sides disagree on substance, ask rather
  than pick.
- **Incoming commits:** read them. If a collaborator changed STATUS.md, CLAUDE.md, or the files
  you are about to work on, summarize what changed before continuing, so the next edits build on
  their work instead of racing it.
- **Push rejected** for permissions: the user may only have read access; say so and suggest a
  fork or asking the owner for write access.

## 4. Report in two or three lines

What was committed, whether it pushed, and anything that came in from collaborators. No
need to restate the whole status file.
