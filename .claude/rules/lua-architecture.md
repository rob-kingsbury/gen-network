# Lua Architecture Rules

**DO NOT REMOVE** - Coding standards for Project Zomboid Lua mod development.

## Core Principles

```yaml
principles:
  - Defensive: Validate all inputs, especially game objects that may be nil or removed
  - MP-Safe: All state changes on server, all syncs explicit
  - KISS: Simple solutions — PZ modding is limited Lua, not enterprise architecture
  - Clarity: Readable code over clever code — future maintainers may not know PZ internals
  - Separation: Shared=logic, Client=UI+commands, Server=execution+sync
```

## Module Pattern

```lua
-- Initialization guard (prevents double-load)
if ModName and ModName.Initialized then
    return
end

-- Global namespace table
ModName = ModName or {}
local MN = ModName  -- Local alias for performance and brevity

-- Constants
MN.ModId = "ModName"
MN.Version = "X.Y.Z"

-- Private functions (local, underscore prefix)
local function _log(msg)
    if MN.DEBUG then
        print(string.format("[ModName %s] %s", tostring(MN.Version), tostring(msg)))
    end
end

-- Public functions (attached to namespace table)
function MN.publicFunction(args)
    -- ...
end

-- Also expose private functions that other modules need
MN.log = _log

-- Mark as initialized
MN.Initialized = true
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Global namespace | PascalCase | `GeneratorNetwork` |
| Local alias | UPPER short | `local GN = GeneratorNetwork` |
| Public functions | camelCase on namespace | `GN.getGeneratorsAround()` |
| Private functions | `_camelCase`, local | `local function _isValidGen()` |
| Constants | UPPER_SNAKE on namespace | `GN.ModId`, `GN.DEBUG` |
| Parameters | camelCase | `playerObj`, `clusterRadius` |
| Loop variables | short lowercase | `i`, `x`, `y`, `z`, `gen`, `sq` |
| Event handlers | `onEventName` | `onClientCommand`, `onFillWorldObjectContextMenu` |

## Validation Pattern

**Always validate game objects before use.** PZ objects can become nil, removed, or invalid between ticks.

```lua
-- Standard generator validation
local function _isValidGen(gen)
    if not gen then return false end
    if not instanceof(gen, "IsoGenerator") then return false end
    local sq = gen:getSquare()
    if not sq then return false end
    if gen.getObjectIndex and gen:getObjectIndex() == -1 then return false end
    return true
end
```

**Rules:**
- Check nil before any method call
- Check instanceof before type-specific methods
- Check getSquare() to confirm object is still in world
- Check getObjectIndex() ~= -1 to confirm not removed
- Re-validate in loops — state can change between iterations

## Error Handling

Lua in PZ has no try/catch. Use defensive checks:

```lua
-- Good: Check before calling
if gen and gen.getFuel then
    local fuel = gen:getFuel() or 0.0
end

-- Good: Default values
local cond = gen.getCondition and gen:getCondition() or 100
local connected = gen.isConnected and gen:isConnected() or false

-- Good: Guard clauses at function start
function MN.doSomething(gens)
    if not gens or #gens == 0 then
        _log("doSomething: no generators")
        return
    end
    -- Main logic
end
```

## Logging

```lua
-- Always use the mod's _log function, never raw print()
_log("Simple message")
_log(string.format("[CATEGORY] detail at %d,%d,%d value=%.3f", x, y, z, val))

-- Category tags for filtering:
-- [CLUSTER] - Generator discovery and grouping
-- [FUEL]    - Fuel distribution operations
-- [POWER]   - Activation/deactivation
-- [COVERAGE]- Visual highlighting (client only)
-- [CL]      - Client-side prefix
-- [SV]      - Server-side prefix
```

## File Organization

### Shared Module (loaded first)
- All business logic
- Validation functions
- Utility functions
- Sandbox option application
- Constants and configuration

### Client Module
- `require "ModName_Shared"` at top
- Context menu handlers
- Visual effects (highlighting, UI)
- Command sending via `sendClientCommand()`
- NO game state modification

### Server Module
- `require "ModName_Shared"` at top
- `Events.OnClientCommand` handler
- Command routing and execution
- All state mutation and syncing
- Player notification

## Anti-Patterns (DO NOT)

```lua
-- DON'T: Access cell without context check
local cell = getCell()  -- Fails on server!
-- DO: Use context-aware wrapper
local cell = isServer() and getWorld():getCell() or getCell()

-- DON'T: Call deprecated methods
gen:activate()    -- Doesn't exist in B42
gen:deactivate()  -- Doesn't exist in B42
-- DO: Use B42 API
gen:setActivated(true)
gen:setSurroundingElectricity()

-- DON'T: Flat SandboxVars access
SandboxVars.GeneratorNetworkDebug  -- Wrong in B42
-- DO: Nested access
SandboxVars.GeneratorNetwork.Debug

-- DON'T: Modify game state on client
gen:setFuel(50)  -- Client-side = desync
-- DO: Send command to server
sendClientCommand("ModId", "Action", { x = x, y = y, z = z })

-- DON'T: Skip validation
for _, gen in ipairs(gens) do
    gen:setFuel(per)  -- gen could be nil/invalid
-- DO: Validate in every loop
for _, gen in ipairs(gens) do
    if _isValidGen(gen) then
        gen:setFuel(per)
    end
end

-- DON'T: Forget to sync in MP
gen:setFuel(per)  -- Clients won't see the change
-- DO: Sync after mutation
gen:setFuel(per)
if isServer() then
    gen:sendObjectChange("fuel")
end
```

## Quality Checklist

Before committing Lua changes:
- [ ] All game objects validated before use
- [ ] State changes only happen on server
- [ ] MP sync calls after all state mutations
- [ ] Debug logging for all significant operations
- [ ] Guard clauses at function start
- [ ] No deprecated B41 API calls
- [ ] Sandbox options accessed with nested path
- [ ] Early returns for invalid/empty inputs
