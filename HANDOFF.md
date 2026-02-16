# Generator Network - Handoff

## Current Priority

**v2.0 Phase 1: Building Power + CO Suppression**

`_Shared.lua` has been rewritten with the v2.0 building power system. Next steps:
1. Rewrite `_Client.lua` — building-aware context menu, building coverage highlight
2. Rewrite `_Server.lua` — new command handlers for BuildingOn/Off, RefuelBuilding
3. Update `sandbox-options.txt` — add TankCapacity (Phase 2 prep)
4. **In-game CO suppression test** — P0 showstopper, must verify OnTick approach works

Full plan: `.claude/plans/typed-wobbling-bubble.md`

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| v2.0 Plan | Approved | 4 phases, 9 risk mitigations documented |
| _Shared.lua v2.0 | Rewritten | Building power, CO suppression, radius fallback |
| _Client.lua v2.0 | NOT STARTED | Still v1.0 cluster-based code |
| _Server.lua v2.0 | NOT STARTED | Still v1.0 command handlers |
| sandbox-options.txt | Needs Update | Add TankCapacity, AutoStartEnabled, AutoStartDelay |
| mod.info | Needs Update | Version bump to 2.0.0 |
| CO Suppression | UNTESTED | P0 risk — OnTick vs Java tick race condition |
| Extended Fuel Tank | Not Started | Phase 2, ModData-based |
| ATS Auto-Start | Not Started | Phase 3, Issue #15, deferrable |
| Silo Generator Sprite | Not Started | Phase 4, Issue #14, needs in-game identification |
| Extension Cord | Not Started | Issue #13, future enhancement |
| MP Fuel Sync | Not Started | Issue #4, from v1.0 |

---

## Blockers

- **CO suppression must be tested in-game** before building the full Client/Server rewrite. If OnTick can't outrace Java's `setToxic(true)`, backup plans: ventilation check via adjacent outdoor squares, or require outdoor placement.

---

## Recent Decisions

| Decision | Why | Date |
|----------|-----|------|
| Building-based power model | Real generators power buildings through wiring, not radius | 2026-02-16 |
| OnTick for CO suppression | EveryOneMinute too slow — Java sets toxic every tick | 2026-02-16 |
| FTS4 instead of FTS5 | sql.js WASM build doesn't include FTS5 | 2026-02-16 |
| Skip pz-mcp-server | Neither version useful for Lua mod dev | 2026-02-16 |
| Flat GN_ ModData keys | Avoid KahluaTable serialization issues with nested tables | 2026-02-16 |
| Radius fallback for non-building | Player-built structures return nil from getBuilding() | 2026-02-16 |
| Issues #13-15 created | Track extension cord, sprite, ATS as separate work items | 2026-02-16 |

---

## What Was Done (Session 2 — 2026-02-16)

### v2.0 Planning
- Deep research: IsoBuilding API, RoomDef, setHaveElectricity, setToxic, ModData, vanilla MOGenerator.lua
- Reviewed prior art: "Generator Powered Buildings" mod (removed from Workshop)
- Created comprehensive plan with phases, risks, verification steps
- Identified P0 showstopper: CO suppression tick race

### _Shared.lua Rewritten
New v2.0 functions:
- `getBuildingForGen(gen)` — building detection with 8-adjacent fallback
- `getAllBuildingSquares(building)` — room-based iteration via RoomDef rects
- `powerBuilding(building, flag)` — set haveElectricity on all building squares
- `refreshBuildingPower(building)` — re-check all generators, only clear if LAST deactivates
- `getGeneratorsInBuilding(building)` — find all valid generators in same building
- `registerBuilding(building)` / `unregisterBuilding(building)` — managed building tracking
- `setGeneratorsActivated(player, gens, flag)` — replaces old setClusterActivated
- OnTick handler for CO fume suppression
- EveryOneMinute handler for building power maintenance

### GitHub Issues Created
- #13: Extension cord / outbuilding power
- #14: Silo generator sprite identification
- #15: ATS auto-start

### Side Quest: pz-mcp-server Port
- Ported to sql.js (WASM), zero native deps, clean build
- Determined it's not useful for our Lua mod — script-focused, not Lua-focused
- Code at `c:\xampp\htdocs\pz-mcp-server-port\`

---

## Next Steps

1. **Rewrite _Client.lua** for v2.0 (building-aware context menu)
2. **Rewrite _Server.lua** for v2.0 (new command handlers)
3. **Test CO suppression in-game** (P0 — place generator indoors, activate, sleep)
4. **Update sandbox-options.txt and translations**
5. **Version bump mod.info to 2.0.0**
6. Phase 2: Extended fuel tank
7. Phase 3: ATS auto-start (Issue #15, defer if complex)
8. Phase 4: Silo sprite (Issue #14)

---

## Quick Commands

```bash
# Check issues
gh issue list --state open

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
Generator Network — continue with v2.0 Phase 1. _Shared.lua is rewritten.
Next: rewrite _Client.lua and _Server.lua for building power commands.
Read CLAUDE.md and .claude/context.md for full project context.
Plan at .claude/plans/typed-wobbling-bubble.md
```
