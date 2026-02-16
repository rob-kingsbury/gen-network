# Generator Network

A Project Zomboid mod (B42.12+) that provides industrial generator behavior: building-based power delivery, indoor CO suppression, fuel sharing, and coverage highlighting. Radius fallback for outdoor/non-building placement.

**Repo:** `rob-kingsbury/gen-network` | **Mod ID:** `GeneratorNetwork` | **Version:** 2.0.0

---

## SESSION START (REQUIRED)

**Before ANY work**, Claude MUST:

1. **Read context files:**
   - `.claude/context.md` - Project state, recent changes
   - `HANDOFF.md` - Current priorities (if exists)

2. **Check GitHub Issues:**
   ```bash
   gh issue list --state open --limit 10
   ```

3. **Output confirmation:**
   ```
   Generator Network ready. [X] open issues. Priority: Issue #XX
   Files loaded: context.md, HANDOFF.md
   ```

**DO NOT skip. DO NOT begin work without this confirmation.**

---

## COMMUNICATION STYLE

- Facts only. No fluff, no hedging, no praise.
- "I don't know" when uncertain.
- Disagree when the user is wrong.
- Research before building (check prior art, PZ API docs).

---

## TODO = GITHUB ISSUE

When user says "todo", "add to backlog", "remember to":
- Create a GitHub Issue immediately
- Confirm: "Created Issue #XX: [title]"

---

## PROJECT ARCHITECTURE

```
GeneratorNetwork_42/
├── mod.info                              # Mod metadata (B42 format)
└── 42/                                   # Build 42 content root
    ├── poster.png                        # Workshop thumbnail
    └── media/
        ├── sandbox-options.txt           # Configurable parameters (VERSION = 1)
        └── lua/
            ├── client/
            │   └── GeneratorNetwork_Client.lua   # UI, context menu, coverage vis
            ├── server/
            │   └── GeneratorNetwork_Server.lua   # Command handler, game logic exec
            └── shared/
                ├── GeneratorNetwork_Shared.lua   # Core logic (cluster, fuel, power)
                └── Translate/EN/
                    └── Sandbox_EN.txt            # English UI strings
```

### Three-Tier Architecture

| Layer | File | Runs On | Responsibility |
|-------|------|---------|----------------|
| **Shared** | `_Shared.lua` | Both | Building detection, power delivery, CO suppression, fuel distribution, validation |
| **Client** | `_Client.lua` | Client | Building/radius context menu, coverage highlighting, `sendClientCommand()` |
| **Server** | `_Server.lua` | Server | `OnClientCommand` handler, building/radius routing, executes shared logic |

### Communication Flow

```
Player right-clicks generator → Client detects building vs outdoor placement
    → Building mode: "Turn Building On/Off", "Refuel Building Generators"
    → Radius mode: "Turn Cluster On/Off", "Refuel Cluster"
    → Client sends command (module, action, {x,y,z})
    → Server receives via OnClientCommand → Finds building or radius cluster
    → Server executes action → Syncs changes, sends result back to client
```

### Key Functions

| Function | Location | Purpose |
|----------|----------|---------|
| `GN.getBuildingForGen(gen)` | Shared | Find IsoBuilding for a generator (+ adjacent square fallback) |
| `GN.getAllBuildingSquares(building)` | Shared | Get all grid squares in a building via RoomDef rects |
| `GN.powerBuilding(building, flag)` | Shared | Set haveElectricity on all building squares |
| `GN.refreshBuildingPower(building)` | Shared | Re-check active generators, clear power if none |
| `GN.setGeneratorsActivated(player,gens,flag,building)` | Shared | Activate/deactivate with building power support |
| `GN.getGeneratorsAround(x,y,z,r)` | Shared | Find generators within radius (outdoor fallback) |
| `GN.distributeFuelEvenly(gens)` | Shared | Pool and equalize fuel across generators |
| `GN.isValidGen(gen)` | Shared | Validate generator (instanceof, square, index) |
| `GN.showBuildingCoverage(building)` | Client | Highlight all building squares |
| `GN.showRadiusCoverage(sq)` | Client | Highlight radius coverage (v1.0 fallback) |
| `onClientCommand(module,cmd,player,args)` | Server | Route building/radius commands to shared logic |

---

## CODING CONVENTIONS

### Lua Style (PZ Mod)

- **Global namespace:** `GeneratorNetwork` table, aliased as `local GN = GeneratorNetwork`
- **Private functions:** Prefixed with `_` and declared `local` (e.g., `local function _log(msg)`)
- **Public functions:** Attached to `GN` table (e.g., `function GN.functionName()`)
- **Logging:** Always use `_log()` which respects `GN.DEBUG` flag
- **Validation:** Always call `_isValidGen(gen)` before operating on generators
- **Guard pattern:** Check `GeneratorNetwork.Initialized` to prevent re-initialization
- **String formatting:** Use `string.format()` for all log messages
- **Early returns:** Return early on nil/invalid input

### PZ API Conventions

- **Cell access:** `getCell()` on client, `getWorld():getCell()` on server — use `_getCell()` wrapper
- **Generator state:** Use `setActivated(bool)` + `setSurroundingElectricity()`, NOT deprecated `activate()`/`deactivate()`
- **MP sync:** Always call `gen:sendObjectChange("fuel")` after `setFuel()` on server
- **Player messages:** Use `playerObj:Say(msg)` for in-game notifications
- **Commands:** `sendClientCommand(module, action, argsTable)` from client to server
- **Context menu:** Hook via `Events.OnFillWorldObjectContextMenu`
- **Coordinates:** Always pass as `{x=, y=, z=}` in command args, `tonumber()` on server

### Sandbox Options

- Format: `VERSION = 1` at top, dotted option names `ModId.Option`
- Access: `SandboxVars.GeneratorNetwork.OptionName` (nested, not flat)
- Translations: `Sandbox_ModId_Option` and `_tooltip` keys in `Translate/EN/Sandbox_EN.txt`

---

## KNOWN ISSUES

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 4 | MP fuel sync may not propagate to clients | OPEN | `sendObjectChange("fuel")` may not trigger client display update. Consider `gen:sync()` |

Issues #1–#3 closed in e556a29. Issues #5–#12 closed in 7fc33d2 (v0.9.0).

---

## QUICK REFERENCE

| Command | Action |
|---------|--------|
| `gh issue list` | View open issues |
| `gh issue view 4` | View MP fuel sync issue |
| `git log --oneline` | Recent commits |

---

## SLASH COMMANDS

| Command | Purpose |
|---------|---------|
| `/session-start` | Load context, check issues, confirm readiness |
| `/handoff` | End session: persist todos, clean workspace, commit, push |

---

## REFERENCE FILES

| File | Purpose | When to Read |
|------|---------|--------------|
| `.claude/context.md` | Project state | Session start |
| `.claude/rules/*.md` | Lua/PZ/workflow rules | Before coding |
| `.claude/commands/*.md` | Slash command definitions | When modifying commands |
| `HANDOFF.md` | Current priorities | Session start |
| `GeneratorNetwork_Shared.lua` | Core logic | Before any logic changes |
| `sandbox-options.txt` | Config format | When adding options |

---

## SESSION END (REQUIRED)

Before ending ANY session:

1. **Tasks → GitHub Issues** (incomplete work = new issue)
2. **Update context.md** (what was done)
3. **Clean workspace:**
   ```bash
   find . -type d \( -name "temp_*" -o -name "test_*" \) -not -path "./.git/*"
   find . -type d -empty -not -path "./.git/*"
   ```
4. **Commit and push**
5. **Tell user:** `Continue with Issue #XX`

---

## PRIVACY FIRST

- No PII in commits, memory, or uploads
- No Steam API keys or server credentials in code
