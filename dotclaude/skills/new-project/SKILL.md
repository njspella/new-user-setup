---
name: new-project
description: >-
  Start (or bootstrap) a project by name: `/new-project <name>`. Makes sure ~/Claude/<name>
  exists and becomes the working directory, checks whether the logged-in GitHub user
  already has access to a repository called <name> (own, collaborator, or org), creates a private
  one if not, otherwise clones or pulls it, reads what is there, sets up STATUS.md plus collaboration
  conventions when other people share the repo, and briefs the user so work can start. Use this
  whenever the user says "start a new project", "new project called X", "set up a repo for X",
  "create a project folder for X", or wants a fresh project with a GitHub repo behind it, even if
  they do not say "GitHub". To resume a project that is already set up, prefer /continue-project.
---

# New Project

Goal: in one command, the user goes from "I want to work on X" to a local folder under `~/Claude`,
a private GitHub repo behind it, and a short brief of what is already there. The deterministic
parts live in a script so every run behaves the same; your job is the judgment around it.

## 1. Get the name

The first argument is the project name. If it is missing, ask for it; do not invent one.
GitHub repo names allow letters, digits, `.`, `-` and `_`, so if the user gives "My Website"
propose a slug such as `my-website` and confirm before running anything, because the name
becomes both a folder and a repository and renaming later is annoying.

## 2. Run the setup script

```bash
bash ~/.claude/skills/new-project/scripts/setup_project.sh <name>
```

It prints `KEY=VALUE` lines. What it does, so you can explain it and spot problems:

- Creates `~/Claude/<name>` if it does not exist (`DIR_STATE`).
- Searches every repo the gh user can reach (owned, collaborator, organization) for an exact
  name match. Collaborator-owned repos count: a project a family member or teammate created
  and shared is "the" repo for this name, so `REPO_OWNED_BY_OTHER` is normal, not an error.
- No match → creates **private** `<your-login>/<name>` and pushes the folder to it with a README
  and a `.gitignore` (`REPO_STATE=created`).
- Match → clones into an empty folder, pulls fast-forward into an existing clone, or attaches a
  non-empty non-git folder to the remote without deleting local files (`REPO_STATE=cloned |
  pulled | attached-* | fetched-dirty | diverged`).
- Lists `COLLABORATORS` (other logins with access), open issues and PRs, key files, and recent commits.

Read `WARN=` and `ERROR=` lines carefully and tell the user what they mean in plain words.
`fetched-dirty` or `diverged` means local work exists that must not be stomped: show
`git status` and ask before resolving. `REPO_OTHER_MATCHES` means two reachable repos share
the name; say which one was chosen and why (the user's own repo wins).

## 3. Make the folder the working directory

If the `mcp__ccd_directory__change_directory` tool is available (Claude desktop app), call it
with the absolute `DIR` path; the switch takes effect at the end of the turn, so keep using absolute
paths for the rest of this turn. Otherwise `cd` there in Bash, which persists between calls.

## 4. Read the material

For a cloned or pulled repo, read before doing anything: `CLAUDE.md`, `README.md`, `STATUS.md`,
anything that looks like a plan or docs index, and the recent commit log the script printed. If
`OPEN_ISSUES` or `OPEN_PRS` is non-zero, list them with `gh issue list` / `gh pr list` so the
brief reflects what collaborators have queued. The point is to arrive already knowing what the
project is and where it stands, so the user is not asked to re-explain it.

## 5. Scaffold what is missing

- **STATUS.md** if absent: copy `assets/STATUS.md.template`, replacing `{{NAME}}`, `{{DATE}}`
  (today, YYYY-MM-DD) and `{{USER}}` (`GH_USER`). It is the hand-off file both `/continue-project`
  and collaborators rely on, so every project gets one.
- **CLAUDE.md**: for a brand-new project write a short one (what the project is, in the user's
  words, plus conventions once known). For an existing project do not rewrite the owner's file.
- **Collaboration section**: when `COLLABORATORS` is not `none`, append
  `assets/CLAUDE.md.collaboration` to `CLAUDE.md` (create the file if needed), filling
  `{{COLLABORATORS}}` and `{{NAME}}`, unless the `<!-- claude-sync` marker is already present.
  This is how "regularly push changes and status" becomes a standing instruction for every future
  session in that project rather than something the user has to remember.
- Commit and push the scaffolding with `/sync-project` (or run
  `bash ~/.claude/skills/sync-project/scripts/sync.sh "Add STATUS.md and collaboration conventions"`)
  so collaborators get the same conventions immediately.

## 6. Brief and begin

Finish with a short brief, then ask what to work on first:

- Folder and repo (full name, private or not, owner if not the user).
- What happened: created / cloned / pulled, and any warnings.
- Collaborators and anything they have queued (issues, PRs, STATUS.md "Next" items).
- One paragraph on what the project is, from the material you read.

Keep it to the facts the user needs to start. If the project has collaborators, remind the user
once that `/sync-project` pushes work and status at checkpoints and `/continue-project <name>`
resumes with a pull.
