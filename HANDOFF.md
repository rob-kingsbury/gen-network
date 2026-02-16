# Generator Network - Handoff

## Current Priority

**Fix Issue #17 (power leak) and Issue #18 (CO2 regression)**

Session 5 implemented flood-fill structure detection (Phase A) and a power containment system (`scrubLeakedPower` + `containPower`). Both power leaking and CO2 poisoning were reported during testing but the latest code has not been verified on a fresh save yet.

**Test procedure:**
1. Launch PZ, start a **new save**
2. Enable Debug Logging in sandbox options
3. Place generator inside a vanilla building, connect + fuel it
4. Right-click → "Turn Building On"
5. **Check power containment:** power inside building, NOT outside walls
6. **Check CO2:** stay indoors several in-game hours, no sickness moodle
7. Check console for `[SCRUB]` and `[POWER] containPower` log entries
8. Also test player-built structure (flood-fill path) with same checks

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| v2.0 Plan | Approved | 4 phases, 9 risk mitigations documented |
| _Shared.lua v2.0 | Done + Phase A | Flood-fill, power containment, CO suppression |
| _Client.lua v2.0 | Done | Three-way menu (building/structure/radius), Z-filter, green coverage |
| _Server.lua v2.0 | Done | Building/structure/radius handlers with containPower |
| Power containment | **UNTESTED** | `scrubLeakedPower` + `containPower` + chunk deregistration (Issue #17) |
| CO Suppression | **REGRESSED** | Was working, broke after refactor (Issue #18) |
| Extended Fuel Tank | Not Started | Phase 2, ModData-based |
| ATS Auto-Start | Not Started | Phase 3, Issue #15, deferrable |
| Silo Generator Sprite | Not Started | Phase 4, Issues #14, #16 |
| Extension Cord | Not Started | Phase B, Issue #13 |
| MP Fuel Sync | Not Started | Issue #4, from v1.0 |

---

## Blockers

- **Issue #17: Power leak.** Java's `setActivated(true)` internally calls `setSurroundingElectricity()`. Our scrub approach clears the leak after it happens. B42 dual power system (`haveElectricity` + `hasGridPower`) may require chunk-level deregistration on B42.13+. Scrub implemented but untested.
- **Issue #18: CO2 regression.** Likely caused by timing or registration gap after the `setGeneratorsActivated` refactor. Buildings/structures must be registered before `_onTick` CO suppression can work.

---

## Key Research Findings (Session 5)

| Finding | Impact |
|---------|--------|
| `setActivated(true)` calls `setSurroundingElectricity()` internally | Our `containPower` skip was always a no-op |
| B42 has dual power: `haveElectricity` + `hasGridPower()` | Scrubbing legacy field may not be enough on B42.13+ |
| `setHaveElectricity` is deprecated in B42 | Still functional, but TIS may remove it |
| Java does NOT periodically reset `haveElectricity` | Our EveryOneMinute re-application is correct |
| No pure-Lua mod has solved power containment | "Generator Powered Buildings" accepts the leak |
| `update()` does NOT call `setSurroundingElectricity()` every tick | Only on `updateSurrounding` flag (load, chunk events) |

---

## Recent Decisions

| Decision | Why | Date |
|----------|-----|------|
| Active scrub instead of skip | `setActivated()` Java internals bypass any Lua skip | 2026-02-16 |
| Chunk deregistration via pcall | B42.13+ uses `hasGridPower()` which ignores `haveElectricity` | 2026-02-16 |
| Remove `containPower` param | Was always a no-op — Java already called `setSurroundingElectricity()` | 2026-02-16 |
| Flood-fill BFS for structures | Player-built structures return nil from `getBuilding()` | 2026-02-16 |
| Cache building refs in structures | CO suppression needs building refs for structures overlapping vanilla buildings | 2026-02-16 |

---

## Files Modified (Session 5)

| File | Changes |
|------|---------|
| `_Shared.lua` | +473 lines: flood-fill, wall detection, structure power, `scrubLeakedPower`, `containPower`, `cleanupStaleBuildings`, simplified `setGeneratorsActivated` |
| `_Client.lua` | +136 lines: three-way menu, structure coverage, Z-floor filtering, green colors |
| `_Server.lua` | +109 lines: structure handlers, `containPower` calls, removed `containPower` param |
| `development-workflow.md` | +14 lines: mod sync rule |

---

## Next Steps

1. **Test Issue #17 + #18 on a new save** — verify scrub works, CO2 doesn't recur
2. If power still leaks on B42.13+: investigate `removeGeneratorPos` chunk API availability
3. If CO2 recurs: add auto-registration on game load (scan for active gens in buildings)
4. Phase 2: Extended fuel tank (ModData-based)
5. Phase B: Extension cord (Issue #13)

---

## To Resume

```
Generator Network — Fix Issue #17 (power leak) and Issue #18 (CO2 regression).
Session 5 implemented flood-fill + power scrub but both bugs unverified on fresh save.
Read CLAUDE.md and .claude/context.md for full project context.
```
