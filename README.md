# New user Claude setup

Everything needed to give a new person a Claude setup like Noah's, in their own Claude account.
Work through the checklist top to bottom. Sign-ins and connectors can't be copied, so those
steps are by hand. The Claude Code config is installed by `setup.sh`.

## What's in here

| Path | What it is |
|---|---|
| `setup.sh` | Installs Claude Code, git, gh and node (via Homebrew), then copies `dotclaude/` into `~/.claude` without overwriting anything |
| `dotclaude/settings.json` | Claude Code settings: workflows on, light theme |
| `dotclaude/skills/new-project` | `/new-project <name>`: makes `~/Claude/<name>`, finds or creates a private GitHub repo for it, and briefs you |
| `dotclaude/skills/continue-project` | `/continue-project <name>`: switches to a project, pulls collaborators' changes, and says where things stand |
| `dotclaude/skills/sync-project` | `/sync-project`: updates STATUS.md, commits, pulls, pushes |
| `dotclaude/skills/roi-executive-summary` | Builds a Word executive summary / ROI business case for an equipment purchase |

## Checklist

### 0. Coming from ChatGPT (by hand)
- [ ] In ChatGPT settings > Data controls, request a data export and keep the zip as an archive.
- [ ] Ask ChatGPT: "List everything you remember about me, verbatim." Copy the answer.
- [ ] In Claude, turn memory on, paste that answer in a chat and ask Claude to import it
      (the built-in import-memory skill does this).
- [ ] Copy ChatGPT's custom instructions into Claude's Settings > Profile preferences.
- [ ] For each custom GPT you use, make a Claude project with its instructions and files.

| In ChatGPT | In Claude |
|---|---|
| Memory | Memory, imported with the import-memory skill |
| Custom instructions | Profile preferences |
| Custom GPTs | Projects with instructions and files, or skills |
| Projects | Projects |
| Canvas | Artifacts and docs |
| Connectors / apps | Connectors (step 3) |
| Codex | Claude Code (step 6) |

### 1. Account and apps (by hand)
- [ ] Create a Claude account at claude.ai and pick a plan (Pro or Max).
- [ ] Install the Claude desktop app for Mac and sign in.
- [ ] Install the Claude in Chrome extension and sign in.
- [ ] Optional: install the Claude mobile app.
- [ ] Settings: set your name and preferences, and decide whether memory is on.

### 2. Skills and capabilities (by hand, claude.ai Settings > Capabilities)
- [ ] Turn on code execution and file creation.
- [ ] Turn on these built-in skills: docs, google-workspace, computer-use, chrome-browser,
      built-in-browser, deep-research, import-memory, morning, skill-creator, xlsx, pptx, pdf, docx.

### 3. GitHub and connectors (by hand)
- [ ] Make a GitHub account if you don't have one.
- [ ] Connect GitHub to Claude at https://claude.ai/connect-github.
- [ ] Install the Claude GitHub App on the repositories you'll work in.
- [ ] Add any other connectors you want (Google Drive, Gmail, and so on). Each is your own sign-in.

### 4. Desktop work folder (by hand)
- [ ] `setup.sh` creates `~/Claude`. Add that folder in the desktop app so Cowork can use it.
- [ ] Approve the computer link the first time a cloud thread asks for it.

### 5. Claude Code on the web (by hand)
- [ ] Open claude.ai/code and keep the "Default" environment with trusted network access.
- [ ] Add the repositories you'll use.

### 6. Claude Code CLI (scripted)
```bash
git clone https://github.com/njspella/new-user-setup.git
cd new-user-setup
./setup.sh
gh auth login      # your own GitHub account
claude             # your own Claude account
```
Then, inside Claude Code, try `/new-project test-project`.

`setup.sh` is safe to re-run. It keeps any file already in `~/.claude`, so an existing
`settings.json` isn't replaced.

### 7. Project (by hand)
- [ ] In Claude, create a project named "new user setup" and attach your copy of this repo.
      Noah's version of that project has no custom instructions to copy.

## Notes

- `sync.sh` uses macOS `sed -i ''`, so the skills are written for a Mac.
- The ROI skill's example config uses placeholder part numbers in place of the original ones.
- Nothing here holds a password, token or API key. Every sign-in is your own.
