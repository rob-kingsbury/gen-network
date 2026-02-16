# Generator Network

A Project Zomboid mod (B42.12+) that links vanilla generators into fuel-sharing, activation clusters with visual coverage highlighting. Replaces the vanilla per-generator radius model with a networked cluster approach.

**Repo:** `rob-kingsbury/gen-network` | **Mod ID:** `GeneratorNetwork` | **Version:** 0.8.8

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
| **Shared** | `_Shared.lua` | Both | Cluster discovery, fuel distribution, activation logic, validation |
| **Client** | `_Client.lua` | Client | Context menu, coverage highlighting, `sendClientCommand()` |
| **Server** | `_Server.lua` | Server | `OnClientCommand` handler, executes shared logic, syncs state |

### Communication Flow

```
Player right-clicks generator → Client adds context menu options
    → Player clicks option → Client sends command (module, action, {x,y,z})
    → Server receives via OnClientCommand → Finds cluster via getGeneratorsAround()
    → Server executes action → Syncs changes via sendObjectChange()
```

### Key Functions

| Function | Location | Purpose |
|----------|----------|---------|
| `GN.getGeneratorsAround(x,y,z,r)` | Shared | Find all valid generators within radius |
| `GN.distributeFuelEvenly(gens)` | Shared | Pool and equalize fuel across cluster |
| `GN.setClusterActivated(player,gens,flag)` | Shared | Activate/deactivate all generators in cluster |
| `GN.isValidGen(gen)` | Shared | Validate generator (instanceof, square, index) |
| `GN.showClusterCoverageFromSquare(sq)` | Client | Highlight coverage area on floors |
| `onClientCommand(module,cmd,player,args)` | Server | Route commands to shared logic |

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
| 3 | Duplicate mod.info | CLOSED | Fixed in e556a29 |
| 2 | activate()/deactivate() don't exist in B42 | CLOSED | Fixed: using setActivated() + setSurroundingElectricity() |
| 1 | sandbox-options.txt wrong format | CLOSED | Fixed: VERSION = 1, dotted names |

---

## QUICK REFERENCE

| Command | Action |
|---------|--------|
| `gh issue list` | View open issues |
| `gh issue view 4` | View MP fuel sync issue |
| `git log --oneline` | Recent commits |

---

## REFERENCE FILES

| File | Purpose | When to Read |
|------|---------|--------------|
| `.claude/context.md` | Project state | Session start |
| `.claude/rules/*.md` | Lua/PZ/workflow rules | Before coding |
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
