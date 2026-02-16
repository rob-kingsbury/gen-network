# Generator Network - Handoff

## Current Priority

**Issue #4: MP fuel sync** - `sendObjectChange("fuel")` may not propagate fuel display to clients. Investigate `gen:sync(fuel, cond, connected, activated)` as alternative. Needs in-game MP testing.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Core Cluster Logic | Complete | getGeneratorsAround, distributeFuel, setClusterActivated |
| Client UI | Complete | Context menu with 5 options, coverage highlighting |
| Server Commands | Complete | RefuelCluster, ClusterOn, ClusterOff with feedback |
| Sandbox Options | Complete | Debug logging (default off), Cluster radius |
| B42 API Compat | Complete | Fixed in e556a29, refined in 7fc33d2 |
| MP Fuel Sync | Needs Investigation | Issue #4 — sendObjectChange vs sync() |
| Workshop Upload | Not Started | No releases or tags yet |
| Claude Scaffold | Complete | CLAUDE.md, context.md, 4 rules files, HANDOFF.md |
| .gitignore | Complete | Comprehensive patterns for PZ/IDE/OS/tooling |

---

## Blockers

- **Issue #4** needs in-game MP testing to confirm whether `sendObjectChange("fuel")` works or if `gen:sync()` is required

---

## Recent Decisions

| Decision | Why | Date |
|----------|-----|------|
| Use setActivated() + setSurroundingElectricity() | activate()/deactivate() don't exist in B42 | 2026-01-24 |
| VERSION = 1 sandbox format | Required by B42, old format silently fails | 2026-01-24 |
| Nested SandboxVars access | B42 uses dotted option names = nested Lua tables | 2026-01-24 |
| Claude scaffold setup | Codify project knowledge, improve dev workflow | 2026-02-15 |
| Command constants in Shared | Single source of truth, eliminates string duplication | 2026-02-15 |
| Keep translation flat format | Works in-game; wrapper format has conflicting sources | 2026-02-15 |
| Version bump to 0.9.0 | Significant quality improvements across all 3 Lua files | 2026-02-15 |

---

## What Was Done (Session 1 — 2026-02-15)

### Scaffold Created
- CLAUDE.md, .claude/context.md, HANDOFF.md
- .claude/rules/ (pz-modding, lua-architecture, development-workflow, thinking-mode)
- .gitignore (comprehensive)

### Issues #5–#12 Created and Fixed (commit 7fc33d2, v0.9.0)
- #5: Added `common/` folder with `.gitkeep`
- #6: Changed `pzversion` to `versionMin=42.12.0` in mod.info
- #7: Changed Debug default to `false` in sandbox-options.txt
- #8: Added `GN.Commands` constants table in Shared
- #9: Added player feedback on refuel with count and per-gen %
- #10: Improved unconnected warning with specific counts
- #11: Coverage highlights only clear on generator context menus
- #12: Added `sendServerCommand` feedback + `OnServerCommand` handler

### .gitignore Updated
- Added Claude, IDE, OS, temp, archive, Node, Python, PZ runtime, and Workshop patterns

### Commit Not Yet Pushed
- `7fc33d2` is 1 ahead of `origin/main`
- .gitignore update is uncommitted

---

## Next Steps

1. **Commit and push** .gitignore update + close issues
2. **Investigate Issue #4** (MP fuel sync) — test `gen:sync()` in multiplayer
3. **Verify translation file format** — test `Sandbox_EN = { }` wrapper in-game
4. Version bump and first GitHub release/tag when stable
5. Consider improvement backlog items below

---

## Improvement Backlog

- Add generator count and fuel status to context menu labels
- Rate limiting on cluster commands (prevent spam)
- Consider caching cluster membership (invalidate on generator add/remove)
- Explore EveryTenMinutes hook for automatic fuel equalization option
- Tooltip or HUD indicator for cluster status

---

## Quick Commands

```bash
# Check issues
gh issue list --state open

# View MP sync issue
gh issue view 4

# Recent commits
git log --oneline

# Push to remote
git push origin main

# Full diff from last push
git diff origin/main..HEAD
```

---

## To Resume

```
Continue working on Generator Network. Priority: push pending changes, then investigate Issue #4 (MP fuel sync).
Read CLAUDE.md and .claude/context.md for full project context.
```
