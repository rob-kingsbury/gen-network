# Development Workflow Rules

**DO NOT REMOVE** - These rules define how we develop and maintain this project together.

## Core Principles

1. **You direct, Claude builds**: You set priorities and make decisions, I implement and maintain
2. **GitHub Issues for tracking**: All features, bugs, and tasks go in GitHub Issues
3. **Privacy first**: Never commit PII, credentials, or sensitive data
4. **Test in-game**: Lua mods require in-game testing — provide clear test steps
5. **Incremental progress**: Small commits, clear descriptions
6. **Do it right, not right now**: Don't defer work that will need doing anyway

## Working Patterns

### Starting a New Feature

1. Create GitHub Issue with clear scope
2. Read existing code — especially `_Shared.lua` for core logic
3. Implement following the three-tier architecture
4. Add debug logging for all new logic paths
5. Describe in-game test steps for user verification

### Making Changes

1. Read existing files first (never guess at PZ API)
2. Prefer editing over creating new files
3. Keep changes focused on the task
4. No over-engineering — PZ modding favors simplicity
5. Commit with clear messages describing what and why
6. **Sync to PZ mods folder after every change** (see below)

## Mod Sync (REQUIRED)

After **every** code change, sync repo files to the PZ mods folder so the user can test in-game:

```bash
cp -r "c:/xampp/htdocs/gen-network/GeneratorNetwork_42/"* "C:/Users/roban/Zomboid/mods/GeneratorNetwork_42/"
```

**Source:** `c:/xampp/htdocs/gen-network/GeneratorNetwork_42/`
**Destination:** `C:/Users/roban/Zomboid/mods/GeneratorNetwork_42/`

Do NOT wait for the user to ask — sync immediately after editing files.

### When Stuck or Unsure

1. Check PZ API — methods may not exist or be named differently than expected
2. Search for how other PZ mods handle the same problem
3. Ask clarifying questions
4. Present options with trade-offs
5. Never assume PZ API behavior — verify

## Commit Messages

Format:
```
Short description of change

- Detail 1
- Detail 2

Fixes #123

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Auto-Close Issues in Commits

- `Fixes #123` - Closes the issue when merged/pushed
- `Closes #123` - Same as Fixes
- `Resolves #123` - Same as Fixes

No emojis. No "Generated with Claude Code" footer.

## Destructive Actions

**Always require confirmation before:**
- Deleting files or directories
- Force pushing to any branch
- Resetting git history
- Major refactors touching all 3 Lua files

## Before Every Commit

Checklist:
- [ ] No credentials or PII in changed files
- [ ] Changes match the task scope
- [ ] mod.info version updated if releasing
- [ ] Sandbox option changes have matching translations
- [ ] Commit message is clear

## Before Every Push

Checklist:
- [ ] Review `git diff` for sensitive data
- [ ] Ensure .gitignore excludes all sensitive paths

## GitHub Issues

### Workflow
```bash
# View open issues
gh issue list --state open

# Create issue
gh issue create --title "Title" --body "Description" --label "enhancement"

# Close via commit (preferred)
# Include "Fixes #123" in commit message - auto-closes on push

# Manual close (if needed)
gh issue close <number> --comment "Completed in <commit>"
```

## Session Handoff Procedure

**Before ending any session:**

1. **Ensure all tasks are GitHub Issues**
2. **Update context.md** with what was done
3. **Clean the workspace**
4. **Push all changes to GitHub**
5. **Tell user what to continue with:** `Continue with Issue #XX`

## Version Numbering

- Format: `MAJOR.MINOR.PATCH` (e.g., 0.8.8)
- Update in BOTH `mod.info` (modversion) AND `_Shared.lua` (GN.Version)
- Bump PATCH for bug fixes
- Bump MINOR for new features
- Bump MAJOR for breaking changes

---

*These rules evolve as we work together. Update as needed.*
