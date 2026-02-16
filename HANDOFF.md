# Generator Network - Handoff

## Current Priority

**In-game testing (P0 blocker)**

Session 4 completed a full code audit with 9 bug fixes across all 3 Lua files. All changes synced to PZ mods folder. Ready for in-game testing.

**Test procedure:**
1. Launch PZ, verify mod loads on Mods page (no crash)
2. Enable Debug Logging in sandbox options
3. Singleplayer sandbox, find a vanilla building (gas station, house)
4. Place generator inside, connect it, add fuel
5. Right-click → "Turn Building On"
6. Stay indoors for several in-game hours (fast-forward)
7. **Pass:** No CO sickness moodle, building has power
8. **Fail:** CO sickness appears → fallback to outdoor-only or ventilation check

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| v2.0 Plan | Approved | 4 phases, 9 risk mitigations documented |
| _Shared.lua v2.0 | Done + Audited | 6 bugs fixed in Session 4 |
| _Client.lua v2.0 | Done + Audited | 1 fix (removed undocumented isNull API) |
| _Server.lua v2.0 | Done + Audited | 2 fixes (ensureGenInList calls) |
| sandbox-options.txt | Done | Debug, Radius, TankCapacity |
| Sandbox_EN.txt | Fixed | Added table wrapper + page name |
| mod.info | Done | v2.0.0, both root and 42/ copies |
| CO Suppression | **UNTESTED** | P0 risk — OnTick vs Java tick race condition |
| Extended Fuel Tank | Not Started | Phase 2, ModData-based |
| ATS Auto-Start | Not Started | Phase 3, Issue #15, deferrable |
| Silo Generator Sprite | Not Started | Phase 4, Issue #14 |
| Extension Cord | Not Started | Issue #13, future enhancement |
| MP Fuel Sync | Not Started | Issue #4, from v1.0 |

---

## Blockers

- **CO suppression must be tested in-game.** If OnTick can't outrace Java's `setToxic(true)`, backup plans: ventilation check via adjacent outdoor squares, or require outdoor placement.

---

## Recent Decisions

| Decision | Why | Date |
|----------|-----|------|
| Cache gens in ManagedBuildings | OnTick runs ~60/sec, re-scanning building every tick too expensive | 2026-02-16 |
| setSurroundingElectricity on deactivation | Prevents vanilla radius power leak when building gen turns off | 2026-02-16 |
| ensureGenInList helper | Exterior wall generators may not be inside building rooms | 2026-02-16 |
| Remove sq:isNull() | Not in PZ JavaDocs, undocumented API | 2026-02-16 |
| Building-based power model | Real generators power buildings through wiring, not radius | 2026-02-16 |
| OnTick for CO suppression | EveryOneMinute too slow — Java sets toxic every tick | 2026-02-16 |
| Flat GN_ ModData keys | Avoid KahluaTable serialization issues with nested tables | 2026-02-16 |
| Radius fallback for non-building | Player-built structures return nil from getBuilding() | 2026-02-16 |

---

## What Was Done (Session 4 — 2026-02-16)

### Full Code Audit
- 4 parallel research agents: B42 API compat, config files, RoomRect API, OnTick performance
- Line-by-line audit of all 3 Lua files
- 9 total fixes (6 _Shared, 2 _Server, 1 _Client)
- Config/doc fixes: Sandbox_EN.txt, pz-modding.md, context.md

### Key Fixes
1. Table mutation during pairs() — deferred removal pattern
2. Power leak on deactivation — setSurroundingElectricity() call
3. Exterior wall generators — ensureGenInList() helper
4. OnTick perf — cached generator list in ManagedBuildings
5. Redundant powerBuilding call removed
6. DRY: powerBuilding(building, flag, force) parameter

---

## Next Steps

1. **Test in-game** (mods page load, CO suppression P0)
2. Phase 2: Extended fuel tank (ModData-based, `GN_TankFuel` / `GN_TankCapacity`)
3. Phase 3: ATS auto-start (Issue #15, defer if complex)
4. Phase 4: Silo sprite (Issue #14)

---

## Quick Commands

```bash
gh issue list --state open
git log --oneline
git push origin main
git diff origin/main..HEAD
```

---

## To Resume

```
Generator Network — v2.0 Phase 1 code complete + audited (9 fixes).
Next: in-game testing (mods page, CO suppression P0), then Phase 2 extended fuel tank.
Read CLAUDE.md and .claude/context.md for full project context.
```
