---
name: handoff
description: End-of-session procedure that persists todos, cleans workspace, updates docs, and commits.
---

# Session Handoff Skill

Run this at the end of every work session to ensure clean handoff.

## Instructions for Claude

When this skill is invoked:

### Step 1: Check Git Status
```bash
git status
```
If there are uncommitted changes, note them for the commit.

### Step 2: Persist Todos
- Check for any incomplete work or mentioned "todos"
- Create GitHub Issues for each:
  ```bash
  gh issue create --title "Title" --body "Description" --label "enhancement"
  ```
- Record issue numbers created

### Step 3: Clean Workspace
```bash
# Find and report temp directories
find . -type d \( -name "temp_*" -o -name "test_*" -o -name "*_temp" -o -name "*_old" \) -not -path "./.git/*"

# Find empty directories (excluding common/.gitkeep)
find . -type d -empty -not -path "./.git/*"

# Find temp files
find . \( -name "*.bak" -o -name "*.tmp" -o -name "*~" -o -name "*.orig" \) -not -path "./.git/*"

# Find stray data files
ls *.zip *.csv *.log 2>/dev/null
```
Ask user before deleting anything.

### Step 4: Update context.md
Add session notes with:
- Session number (increment from `last_session`)
- Date
- Summary of what was done
- Files modified
- Issues created/closed

Update YAML header:
- `last_session: [new number]`
- `continue_with: "[next priority]"`

### Step 5: Update HANDOFF.md
Update with:
- Current Priority
- Status table
- Any blockers
- Decisions made
- Next steps

### Step 6: Commit
```bash
git add [specific files]
git commit -m "Session [N]: [summary]

- [change 1]
- [change 2]

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Step 7: Push
```bash
git push origin HEAD
```

### Step 8: Output Summary
```
=== HANDOFF COMPLETE ===

Session [N] finished.
- [X] files modified
- [X] issues created
- [X] issues closed

Next session: Continue with Issue #XX ([title])

To resume: "[Project] - continue with Issue #XX"
```

## Never Skip This

**Always run handoff before ending a session.** Skipping causes context loss and duplicated work.
