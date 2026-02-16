# Generator Network - Handoff

## Current Priority

**Issue #4: MP fuel sync** - `sendObjectChange("fuel")` may not propagate fuel display to clients. Investigate `gen:sync(fuel, cond, connected, activated)` as alternative.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Core Cluster Logic | Complete | getGeneratorsAround, distributeFuel, setClusterActivated |
| Client UI | Complete | Context menu with 4 options, coverage highlighting |
| Server Commands | Complete | RefuelCluster, ClusterOn, ClusterOff |
| Sandbox Options | Complete | Debug logging, Cluster radius |
| B42 API Compat | Complete | Fixed in e556a29 |
| MP Fuel Sync | Needs Investigation | Issue #4 — sendObjectChange vs sync() |
| Workshop Upload | Not Started | No releases or tags yet |
| Claude Scaffold | Complete | CLAUDE.md, context.md, rules, HANDOFF.md |

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

---

## Next Steps

1. **Add missing `common/` folder** — Required for B42 mod detection (can be empty)
2. **Verify translation file format** — May need `Sandbox_EN = { }` wrapper (conflicting sources; current flat format works — test in-game before changing)
3. **Fix mod.info** — Change `pzversion=42.12` to `versionMin=42.12.0`
4. **Investigate Issue #4** (MP fuel sync) — test `gen:sync()` method
5. **Change Debug default to `false`** in sandbox-options.txt for release
6. Version bump and first GitHub release/tag when stable

---

## Improvement Backlog

- Add command string constants to eliminate duplication
- Add player feedback on successful refuel ("Cluster refueled: X generators, Y% each")
- Use sendServerCommand to confirm actions back to client
- Improve coverage highlight persistence (don't clear on non-generator context menus)
- Specify which generators are unconnected in warning message
- Add generator count and fuel status to context menu labels
- Rate limiting on cluster commands (prevent spam)
- Consider caching cluster membership (invalidate on generator add/remove)
- Explore EveryTenMinutes hook for automatic fuel equalization option

---

## Quick Commands

```bash
# Check issues
gh issue list --state open

# View MP sync issue
gh issue view 4

# Recent commits
git log --oneline

# Full diff
git diff
```

---

## To Resume

```
Continue working on Generator Network. Priority: Issue #4 (MP fuel sync investigation).
```
