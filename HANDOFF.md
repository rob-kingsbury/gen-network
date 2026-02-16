# Generator Network - Handoff

## Current Priority

**In-game CO suppression test (P0 blocker)**

All v2.0 Phase 1 code is written. Before proceeding to Phase 2, must verify that `OnTick` can outrace Java's `IsoGenerator.update()` which sets `building:setToxic(true)` every tick.

**Test procedure:**
1. Enable Debug Logging in sandbox options
2. Singleplayer sandbox, find a vanilla building (gas station, house)
3. Place generator inside, connect it, add fuel
4. Right-click → "Turn Building On"
5. Stay indoors for several in-game hours (fast-forward)
6. **Pass:** No CO sickness moodle, building has power
7. **Fail:** CO sickness appears → fallback to outdoor-only or ventilation check

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| v2.0 Plan | Approved | 4 phases, 9 risk mitigations documented |
| _Shared.lua v2.0 | Done | Building power, CO suppression, radius fallback |
| _Client.lua v2.0 | Done | Building-aware context menu, building/radius coverage |
| _Server.lua v2.0 | Done | Building + radius command handlers |
| sandbox-options.txt | Done | Debug, Radius, TankCapacity |
| mod.info | Done | v2.0.0, updated description |
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
| Building-based power model | Real generators power buildings through wiring, not radius | 2026-02-16 |
| OnTick for CO suppression | EveryOneMinute too slow — Java sets toxic every tick | 2026-02-16 |
| Flat GN_ ModData keys | Avoid KahluaTable serialization issues with nested tables | 2026-02-16 |
| Radius fallback for non-building | Player-built structures return nil from getBuilding() | 2026-02-16 |

---

## What Was Done (Session 3 — 2026-02-16)

### Client + Server Rewrite
- `_Client.lua`: building-aware context menu, `showBuildingCoverage()`, `showRadiusCoverage()`, dual result handler
- `_Server.lua`: `_getGenAt()` helper, building/radius command routing, all handlers send feedback
- `_Shared.lua`: added `RadiusResult` command constant

### Sandbox + Metadata
- Added `TankCapacity` option (integer, 10-5000, default 500) with translation
- Bumped mod.info to v2.0.0

---

## Next Steps

1. **Test CO suppression in-game** (P0 — place generator indoors, activate, stay for hours)
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
Generator Network — v2.0 Phase 1 code complete. All 3 Lua files rewritten.
Next: in-game CO suppression test (P0), then Phase 2 extended fuel tank.
Read CLAUDE.md and .claude/context.md for full project context.
```
