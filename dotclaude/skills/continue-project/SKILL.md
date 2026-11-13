---
name: continue-project
description: >-
  Switch to (or resume) an existing project under ~/Claude by name: `/continue-project <name>`.
  Syncs the project being left if it has unsaved work, moves the working directory to
  ~/Claude/<name>, pulls collaborators' changes, reads STATUS.md / CLAUDE.md / recent commits,
  and briefs the user on where things stand and what is next. Use this whenever the user says
  "continue X", "back to X", "switch to the X project", "pick up where we left off on X", "what's
  the status of X", or names a project they worked on before. With no name, it lists the projects
  so the user can choose. For a project that does not exist yet, use /new-project instead.
---

# Continue Project

Switching projects is where context gets lost: uncommitted work left behind, a collaborator's
pushes never pulled, the plan from last time forgotten. This skill makes the switch a clean
hand-off in both directions.

## 1. Leave the current project cleanly

If the session is currently inside a different `~/Claude/<project>` git repo, check
`git status --porcelain` there. If anything is uncommitted or unpushed, run the sync-project
skill (`bash ~/.claude/skills/sync-project/scripts/sync.sh "<message>" <that-dir>`, after a
quick STATUS.md update) before leaving, and say so in one line. Work that stays local is work a
collaborator cannot see, and the user will not remember to push it from the other project.

## 2. Find the project

```bash
bash ~/.claude/skills/continue-project/scripts/project_status.sh [name]
```

With no name it prints every folder under `~/Claude` with its repo, last commit, and whether it
has uncommitted changes; show that list and ask which one. If the name is close to one folder
(case or punctuation differs), use that folder rather than failing. If the folder truly does not
exist, offer `/new-project <name>`.

## 3. Read the output, then the files

The script fetches, fast-forward pulls when the tree is clean, and prints `KEY=VALUE` lines:
`UNCOMMITTED`, `AHEAD_BEHIND`, `INCOMING_COMMITS` and `INCOMING_FILES` (what collaborators
pushed since last time), `COLLABORATORS`, open issues and PRs, recent commits, commits by other
people in the last two weeks, and recently changed files.

Then read, in this order: `STATUS.md` (where we left off), `CLAUDE.md` (the project's rules),
and any file `INCOMING_FILES` or STATUS.md's "Now / Next" sections point at. If a collaborator
changed STATUS.md or CLAUDE.md, diff it (`git diff <before>..HEAD -- STATUS.md`) so you can say
what they changed, not just that they changed it.

Act on `WARN=` lines: a diverged branch or uncommitted-plus-behind state means run `/sync-project`
(with the user's go-ahead if the conflicts look substantive) before starting new work.

## 4. Switch the working directory

Call `mcp__ccd_directory__change_directory` with the absolute `DIR` if that tool exists (Claude
desktop app); the move lands at the end of the turn, so use absolute paths until then. Otherwise
`cd` in Bash.

## 5. Brief and resume

Give a short brief, then propose the next step rather than asking an open question:

- **Where we left off:** the STATUS.md "Now" and "Done recently" items, in one or two lines.
- **What changed since:** collaborators' commits and any issues or PRs they opened, with a line
  on what each means for the work.
- **Next:** the first item from STATUS.md "Next", or the obvious continuation, as a concrete
  proposal ("Shall I pick up the resume rewrite at section 3?").

If the project has collaborators, sync at checkpoints while working (see the collaboration section
in its CLAUDE.md) and again before switching away.
