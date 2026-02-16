---
project: Generator Network
description: PZ mod — industrial generator system with building-based power, CO suppression, extended fuel tanks
last_session: 5
continue_with: "Fix Issue #17 (power leak) and Issue #18 (CO2 regression) — test on new save"

tech:
  stack: pz-lua-mod
  tools: [Lua 5.1 (Kahlua2), Project Zomboid B42.12+, Git, GitHub]

paths:
  src: GeneratorNetwork_42/42/media/lua/
  mod_root: GeneratorNetwork_42/
  rules: .claude/rules/
  shared: GeneratorNetwork_42/42/media/lua/shared/
  client: GeneratorNetwork_42/42/media/lua/client/
  server: GeneratorNetwork_42/42/media/lua/server/

commands:
  issues: gh issue list --state open
  log: git log --oneline
---

# Generator Network Context

## Project Overview

A Project Zomboid mod (Build 42.12+) that provides industrial generator behavior: building-based power delivery, indoor CO fume suppression, extended fuel tanks, and automatic startup on power loss.

**v1.0 (completed):** Radius-based generator clusters with fuel sharing, batch activation, coverage highlighting.

**v2.0 (in progress):** Complete reimagining as realistic industrial generator system:
- Generators power entire buildings through wiring (not radius)
- Safe indoor operation (CO fume suppression via OnTick)
- Extended fuel tank via ModData (500L default)
- Auto-start on grid power failure (ATS behavior — deferrable)
- Silo generator sprite (deferrable)
- Radius fallback for non-building placement

**Tech Stack:** Lua 5.1 (Kahlua2 JVM implementation), Project Zomboid Java API exposed to Lua

## Current Phase

- **v1.0**: Core cluster system (COMPLETE — v0.9.0)
- **v2.0 Phase 1**: Building power + CO suppression (CODE COMPLETE — all 3 Lua files rewritten, needs in-game CO test)
- **v2.0 Phase 2**: Extended fuel tank via ModData (PENDING)
- **v2.0 Phase 3**: ATS auto-start (PENDING — Issue #15, deferrable)
- **v2.0 Phase 4**: Silo generator sprite (PENDING — Issue #14)

## Open Issues

| # | Title | Labels | Priority |
|---|-------|--------|----------|
| 17 | Power leaks outside building/structure boundaries | bug | HIGH |
| 18 | CO2 poisoning recurs after power containment refactor | bug | HIGH |
| 4 | MP fuel sync may not propagate to clients | bug | MEDIUM |
| 13 | Extension cord: extend power to outbuildings via electrical wire | enhancement | LOW |
| 14 | Silo generator sprite: identify and register industrial prop | enhancement | LOW |
| 15 | ATS auto-start: activate generators on grid power loss | enhancement | MEDIUM |
| 16 | Silo generator: re-skin as moveable multi-part prop | enhancement | LOW |

## Closed Issues

| # | Title | Closed In |
|---|-------|-----------|
| 1 | sandbox-options.txt uses wrong format for Build 42 | e556a29 |
| 2 | activate()/deactivate() methods don't exist on IsoGenerator in B42 | e556a29 |
| 3 | Duplicate mod.info causes potential load issues | e556a29 |
| 5 | Missing common/ folder required for B42 mod detection | 7fc33d2 |
| 6 | mod.info uses pzversion instead of versionMin | 7fc33d2 |
| 7 | Debug sandbox option defaults to true | 7fc33d2 |
| 8 | Command action strings duplicated between client and server | 7fc33d2 |
| 9 | No player feedback after Refuel Cluster | 7fc33d2 |
| 10 | Unconnected generator warning is generic | 7fc33d2 |
| 11 | Coverage highlights clear on any context menu | 7fc33d2 |
| 12 | Server does not send feedback to client | 7fc33d2 |

## Commit History

| Hash | Description | Version |
|------|-------------|---------|
| e7d8efd | Initial upload of mod files | v0.8.8 |
| e556a29 | Fix B42 API compatibility (closes #1, #2, #3) | v0.8.8 |
| 7fc33d2 | Add scaffold, fix issues #5-#12, version bump | v0.9.0 |
| 3391a99 | Session 1: Add slash commands, update scaffold docs | v0.9.0 |

---

## v2.0 Plan Summary

Full plan at `.claude/plans/typed-wobbling-bubble.md`.

### Key APIs Confirmed
- `sq:getBuilding()` → IsoBuilding (nil for player-built)
- `building:getDef():getRooms()` → ArrayList of RoomDef (each has getRects() → RoomRect with x,y,w,h fields)
- `sq:setHaveElectricity(bool)` → per-square power control
- `building:setToxic(false)` → CO fume suppression
- `gen:getModData()` → KahluaTable for extended fuel state

### P0 Risk: CO Suppression
Java `IsoGenerator.update()` calls `building:setToxic(true)` every tick. Must use `Events.OnTick` (not EveryOneMinute) to clear. **Must prototype in-game before building other features.**

### Architecture Changes (v2.0)
- Building-based power: `getBuildingForGen()` → `getAllBuildingSquares()` → `powerBuilding()`
- Radius fallback for non-building placement (preserves v1.0 behavior)
- ModData keys namespaced with `GN_` prefix (flat, not nested)
- All ModData writes server-side; client queries via commands

---

## Codebase Stats

| Metric | Value |
|--------|-------|
| Mod version | 2.0.0 |
| Open issues | 7 (#4, #13-#18) |
| Closed issues | 11 (#1-#3, #5-#12) |
| Branches | 1 (main) |

## Architecture Notes

- **Initialization guard:** `GeneratorNetwork.Initialized` flag prevents double-load
- **Building detection:** `getBuildingForGen()` checks generator square + 8 adjacent (exterior wall fallback)
- **Building power:** `powerBuilding()` iterates room rects, sets `haveElectricity()` on all squares
- **CO suppression:** `OnTick` handler clears `setToxic(false)` every tick for managed buildings
- **Managed buildings:** Tracked in `GN.ManagedBuildings` table, keyed by building reference
- **Radius fallback:** Non-building generators use v1.0 cluster behavior
- **Command constants:** `GN.Commands` table — BuildingOn/Off, RefuelBuilding, RadiusOn/Off, RefuelRadius
- **Server feedback:** All operations send result back to client

---

## Session Notes

### Session 0 (2026-02-15): Project Scaffolded

**Setup:**
- Full codebase audit (402 lines across 3 Lua files)
- GitHub repo analysis (2 commits, 4 issues, 1 open)
- PZ B42 generator/power API deep dive
- Created Claude Code scaffold structure

**Files created:**
- CLAUDE.md, .claude/context.md, HANDOFF.md
- .claude/rules/ (pz-modding, lua-architecture, development-workflow, thinking-mode)

### Session 1 (2026-02-15): Issues Fixed, v0.9.0

**Changes:**
- Created and fixed GitHub issues #5–#12 (commit 7fc33d2)
- Version bumped from 0.8.8 to 0.9.0
- All three Lua files significantly improved
- .gitignore expanded with comprehensive patterns
- Closed issues #5–#12 on GitHub

### Session 2 (2026-02-16): v2.0 Plan + _Shared.lua Rewrite

**Planning:**
- Deep research into real-world industrial generator behavior
- Investigated PZ APIs: IsoBuilding, RoomDef, setHaveElectricity, setToxic, ModData
- Reviewed prior art: "Generator Powered Buildings" mod (3597471949, removed)
- Reviewed vanilla MOGenerator.lua for sprite registration patterns
- Created comprehensive v2.0 plan with 4 phases and 9 risk mitigations
- Plan approved and saved to `.claude/plans/typed-wobbling-bubble.md`

**Implementation:**
- Rewrote `_Shared.lua` for v2.0: building power, CO suppression, radius fallback, managed buildings
- New functions: getBuildingForGen, getAllBuildingSquares, powerBuilding, refreshBuildingPower, registerBuilding, unregisterBuilding, setGeneratorsActivated
- OnTick handler for CO fume suppression
- EveryOneMinute handler for building power maintenance

**GitHub Issues Created:**
- #13: Extension cord / outbuilding power
- #14: Silo generator sprite identification
- #15: ATS auto-start

**Side quest:**
- Ported pz-mcp-server from better-sqlite3 to sql.js (pure WASM, no native deps)
- Fixed 30+ pre-existing TypeScript errors, FTS5→FTS4 downgrade
- Investigated wink-'s full GitHub — determined neither MCP server is useful for our Lua mod work

**Not yet done:**
- In-game CO suppression prototype test (P0 — must do before other features)

### Session 3 (2026-02-16): Phase 1 Code Complete

**Implementation:**
- Rewrote `_Client.lua` for v2.0: building-aware context menu, building coverage highlighting, radius fallback
- Rewrote `_Server.lua` for v2.0: building + radius command routing, proper `setGeneratorsActivated` calls
- Added `RadiusResult` command constant to `_Shared.lua`
- Added `TankCapacity` sandbox option (integer, 10-5000, default 500) + translation
- Bumped `mod.info` to v2.0.0 with updated description
- Updated Radius tooltip to mention outdoor/non-building context

**Client v2.0 key changes:**
- `getBuildingForGen()` determines building vs radius mode on right-click
- Building mode: "Turn Building On/Off", "Refuel Building Generators", "Show Building Coverage"
- Radius fallback: "Turn Cluster On/Off", "Refuel Cluster", "Show Cluster Coverage"
- `showBuildingCoverage(building)` highlights all building squares
- `showRadiusCoverage(sq)` preserves v1.0 radius highlighting
- Server response handler accepts both `BuildingResult` and `RadiusResult`

**Server v2.0 key changes:**
- `_getGenAt(x,y,z)` helper for coordinate-based generator lookup
- Building commands: gen lookup → `getBuildingForGen` → `getGeneratorsInBuilding` → execute
- Radius commands: `getGeneratorsAround` → execute without building param
- All handlers send proper feedback via `sendServerCommand`

**Not yet done:**
- In-game CO suppression prototype test (P0 — must do before relying on building power)

### Session 4 (2026-02-16): Full Code Audit

**Audit:**
- Launched 4 parallel research agents: B42.12+ API compat, config files, RoomRect API, OnTick performance
- Manual line-by-line audit of all 3 Lua files

**Bugs fixed in _Shared.lua (6):**
1. Table mutation during `pairs()` in `_onEveryOneMinute` — collect removal IDs in separate list
2. Vanilla radius power leak on building deactivation — added `setSurroundingElectricity()` call
3. Exterior wall generators missed by `getGeneratorsInBuilding` — added `ensureGenInList()` helper
4. OnTick performance — cached generator list in `ManagedBuildings` entries instead of re-scanning
5. Removed redundant `powerBuilding` call after `refreshBuildingPower`
6. DRY: merged power-clear logic into `powerBuilding(building, flag, force)` parameter

**Fixes in _Server.lua (2):**
- Added `ensureGenInList(gens, gen)` calls in both building handlers

**Fixes in _Client.lua (1):**
- Removed undocumented `sq:isNull()` API call

**Config/doc fixes:**
- `Sandbox_EN.txt`: Added `Sandbox_EN = { }` table wrapper + page name entry
- `pz-modding.md`: Fixed mod.info placement docs (42/mod.info IS required by B42)
- `context.md`: Fixed RoomRect field documentation (w,h not x2,y2)

**Not yet done:**
- In-game CO suppression test (P0)
- Phase 2: Extended fuel tank via ModData

### Session 5 (2026-02-16): Flood-fill structures, in-game testing, power containment research

**Phase A implemented: Flood-fill structure detection**
- BFS flood-fill from generator square, bounded by walls, doors passable
- Three-tier detection: `getBuilding()` → flood-fill → radius fallback
- `ManagedStructures` table tracks player-built structures
- CO suppression extended to structures via cached building refs

**In-game testing revealed 4 bugs:**
1. CO poisoning in player-built structures (fixed via cached building refs)
2. Coverage showing all Z floors overlapping (fixed: Z-level filtering)
3. Warehouse retains power after generator moved (fixed: `cleanupStaleBuildings()`)
4. Power leaks outside building boundaries (partially addressed — see below)

**Deep research into PZ Java internals (3 parallel agents):**
- `setActivated(true)` internally calls `setSurroundingElectricity()` — our `containPower` skip was always a no-op
- B42 has dual power: legacy `haveElectricity` + chunk-based `hasGridPower()`
- `setHaveElectricity` is deprecated in B42 but functional
- No pure-Lua PZ mod has solved power containment
- Java does NOT periodically reset the `haveElectricity` field

**Power containment approach (implemented, untested):**
- `scrubLeakedPower()`: clears `haveElectricity` outside building + tries chunk deregistration via pcall
- `containPower()`: powers building squares + scrubs leaked radius
- `setGeneratorsActivated()` simplified: removed useless `containPower` param and explicit `setSurroundingElectricity()` calls
- Server handlers call `containPower()` after activation
- `_onEveryOneMinute` uses `containPower()` for periodic maintenance

**Other fixes:**
- Coverage colors changed to green matching vanilla
- `isServer()` guard changed to `isClient()` for single-player compatibility
- Added mod sync rule to development workflow

**Issues created:** #16, #17, #18
**Bugs remaining:** #17 (power leak), #18 (CO2 regression)
