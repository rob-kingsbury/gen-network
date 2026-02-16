# Project Zomboid B42 Modding Reference

**DO NOT REMOVE** - Domain knowledge for developing PZ mods targeting Build 42.12+.

## Mod File Structure (B42)

```
ModName/
├── mod.info                    # Required: mod metadata (root only, NOT in 42/)
├── common/                     # REQUIRED even if empty — B42 mod detection needs this
└── 42/                         # Build 42 content folder
    ├── poster.png              # Workshop thumbnail (256x256 recommended)
    └── media/
        ├── sandbox-options.txt # Optional: configurable parameters
        └── lua/
            ├── client/         # Client-only scripts (UI, rendering, input)
            ├── server/         # Server-only scripts (game logic, state)
            └── shared/         # Loaded on both client and server (loaded FIRST)
                └── Translate/
                    └── EN/
                        └── Sandbox_EN.txt  # English translations
```

**CRITICAL:** The `common/` folder MUST exist (even if empty) for B42 to detect the mod.

### mod.info Format

```
name=Human Readable Name
id=ModId
description=One-line description
modversion=X.Y.Z
versionMin=42.12.0
poster=42/poster.png
```

**Available fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique mod identifier, must match SandboxVars namespace |
| `name` | Yes | Display name in mod manager |
| `description` | Recommended | Text description |
| `poster` | Recommended | Path to mod manager image (e.g., `42/poster.png`) |
| `modversion` | Optional | Mod version string |
| `versionMin` | Optional | Minimum game version (e.g., `42.12.0`) |
| `versionMax` | Optional | Maximum compatible game version |
| `require` | Optional | Comma-separated required mod IDs |
| `incompatible` | Optional | Comma-separated incompatible mod IDs |
| `author` | Optional | Creator name |
| `url` | Optional | Homepage or workshop link |

- No quotes around values. One field per line
- **Note:** `pzversion` may work but `versionMin` is the documented B42 field

### sandbox-options.txt Format (B42)

```
VERSION = 1,

option ModId.OptionName
{
    type = boolean, default = true,
    page = ModId,
    translation = ModId_OptionName,
}

option ModId.IntOption
{
    type = integer, min = 1, max = 100, default = 10,
    page = ModId,
    translation = ModId_IntOption,
}
```

- `VERSION = 1` required at top (with comma)
- Option names are dotted: `ModId.Option`
- Types: `boolean`, `integer`, `double`, `string`, `enum`
- Each option block ends with `}`
- Access in Lua: `SandboxVars.ModId.Option` (nested table, NOT flat)

### Translation File Format

Translation files must be wrapped in a table definition:

```lua
Sandbox_EN = {
    Sandbox_ModId = "Page Display Name",
    Sandbox_ModId_OptionName = "Display Label",
    Sandbox_ModId_OptionName_tooltip = "Description shown on hover.",
}
```

- **May need** `Sandbox_EN = { }` table wrapper (B41 style) OR flat format (B42 may accept both)
- Include a page name entry: `Sandbox_ModId = "Name"`
- **VERIFY IN-GAME:** Current mod uses flat format and works — test before changing
- Keys follow `Sandbox_ModId_Option` pattern
- Comma after each line
- Tooltip key adds `_tooltip` suffix

---

## Client/Server/Shared Architecture

### When to use each:

| Location | Use For | Available APIs |
|----------|---------|----------------|
| **shared/** | Business logic, validation, utilities | Basic Lua, `instanceof`, `isServer()`, `isClient()` |
| **client/** | UI, context menus, rendering, input | `getCell()`, `getSpecificPlayer()`, UI APIs, `sendClientCommand()` |
| **server/** | Command handling, state mutation, sync | `getWorld():getCell()`, `sendObjectChange()`, `Events.OnClientCommand` |

### Client → Server Communication

```lua
-- CLIENT: Send command
sendClientCommand("ModId", "ActionName", { x = x, y = y, z = z, key = value })

-- SERVER: Receive command
local function onClientCommand(module, command, playerObj, args)
    if module ~= "ModId" then return end
    -- args contains the table sent from client
    -- playerObj is the player who sent the command
end
Events.OnClientCommand.Add(onClientCommand)
```

### Server → Client Communication

```lua
-- Server to ALL clients:
sendServerCommand("ModId", "CommandName", {key1 = val1})

-- Server to SPECIFIC client:
sendServerCommand(playerObj, "ModId", "CommandName", {key1 = val1})

-- Client handler:
local function onServerCommand(module, command, args)
    if module ~= "ModId" then return end
    -- handle response
end
Events.OnServerCommand.Add(onServerCommand)
```

### Object State Sync

```lua
-- After modifying an IsoObject on server:
object:sendObjectChange("propertyName")

-- For IsoGenerator specifically, the sync() method may be more reliable:
gen:sync(fuel, condition, connected, activated)
```

---

## IsoGenerator API Reference

**Package:** `zombie.iso.objects` | **Extends:** `IsoObject`

### State Getters/Setters

| Method | Returns | Description |
|--------|---------|-------------|
| `getX()`, `getY()`, `getZ()` | int | World tile coordinates |
| `getSquare()` | IsoGridSquare | Grid square the generator occupies |
| `getFuel()` | float | 0.0 to ~100.0, represents liters of fuel |
| `setFuel(amount)` | void | Set fuel level |
| `getCondition()` | int | 0-100, integer. Java hard-caps at 100 |
| `setCondition(int)` | void | Set condition. Cannot exceed 100 |
| `isActivated()` | boolean | Whether generator is currently running |
| `setActivated(flag)` | void | Turn on/off. Does NOT propagate electricity — must call setSurroundingElectricity() separately |
| `isConnected()` | boolean | Whether player has "Connected" the generator (Electrical 3 or magazine) |
| `setConnected(flag)` | void | Set connection flag |
| `getObjectIndex()` | int | World object index (-1 = removed/invalid) |

### Power/Electricity Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `setSurroundingElectricity()` | void | Iterates squares within power radius, sets haveElectricity. **Does NOT check overlapping generators** — turning OFF one gen removes power from shared squares |
| `isPoweringSquare(gx,gy,gz,x,y,z)` | static boolean | Tests whether gen at (gx,gy,gz) covers square (x,y,z) |
| `getItemsPowered()` | ArrayList | List of powered device descriptions |
| `getTotalPowerUsing()` | float | Total power draw in L/h |

### Lifecycle Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `addToWorld()` | void | Registers generator, calls setSurroundingElectricity() if active |
| `removeFromWorld()` | void | Unregisters, removes power from surrounding squares |
| `update()` | void | Called every tick when active — handles fuel drain, condition degradation, fire check |
| `failToStart()` | void | Plays failure sound/animation. Does NOT change activated state |

### Network Methods (inherited from IsoObject)

| Method | Args | Description |
|--------|------|-------------|
| `sendObjectChange(field)` | string | Sends named state change to clients. Valid: `"fuel"` |
| `sendObjectChange(field, table)` | string, KahluaTable | Variant with data table |
| `sync(fuel, cond, connected, activated)` | float, int, bool, bool | Full state sync (B42) — may be more reliable than sendObjectChange |

### DEPRECATED (DO NOT USE in B42)

| Method | Replacement |
|--------|-------------|
| `activate()` | `setActivated(true)` + `setSurroundingElectricity()` |
| `deactivate()` | `setActivated(false)` + `setSurroundingElectricity()` |

### Validation Pattern

```lua
local function isValidGen(gen)
    if not gen then return false end
    if not instanceof(gen, "IsoGenerator") then return false end
    local sq = gen:getSquare()
    if not sq then return false end
    if gen.getObjectIndex and gen:getObjectIndex() == -1 then return false end
    return true
end
```

### Grid Square Generator Access

```lua
local sq = cell:getGridSquare(x, y, z)
if sq then
    local gen = sq:getGenerator()  -- Returns IsoGenerator or nil
end
```

---

## How Vanilla Generators Work

### Setup Sequence
1. **Placement:** Player places generator item → `addToWorld()` called
2. **Connection:** Player uses "Connect Generator" (requires Electrical 3 or "How to Use Generators" magazine) → `setConnected(true)`
3. **Fueling:** Player adds fuel cans (generator must be OFF). Tank holds ~10 liters → `setFuel()`
4. **Activation:** Player toggles generator → `setActivated(true)` + `setSurroundingElectricity()`

### The update() Tick Loop (when activated)
1. **Fuel drain:** Base 0.002 L/h idle + device draw (fridge ~0.016, TV ~0.003, lamp ~0.0002 L/h). Multiplied by `SandboxVars.GeneratorFuelConsumption` and time speed
2. **Condition degradation:** Loses ~1 point every few in-game hours
3. **Fire check:** If condition <= 20, random chance triggers fire on generator's square
4. **Fuel exhaustion:** If fuel reaches 0 → auto-deactivates + setSurroundingElectricity()

### Power Radius
- **Horizontal:** 20 tiles default. Sandbox option `GeneratorTileRange` (1-100)
- **Vertical:** 3 floors default. Sandbox option `GeneratorVerticalPower` (1-15)
- **Shape:** Cylinder centered on generator (diameter 41, height 7 floors at defaults)
- **B42 building grids:** Pre-built vanilla buildings may have power grids that generators power entirely regardless of radius

### setSurroundingElectricity() Behavior
1. Iterates all IsoGridSquare within power radius (horizontal + vertical)
2. Sets `haveElectricity(true)` if activated, `false` if deactivated
3. Calls `checkHaveElectricity()` on each IsoObject in range
4. **CRITICAL QUIRK:** Does NOT check overlapping generators. Turning OFF one generator removes power from squares another generator also covers

### isConnected() Meaning
- Simple boolean flag set by `setConnected(boolean)`
- Returns `true` if player has performed "Connect Generator" action
- **Prerequisite for activation** — unconnected generators cannot turn on
- Persists across save/load
- Per-generator, not per-cluster — each needs individual connection
- NOT related to fuel, power grid, or wiring — purely "has been wired" flag

### Vanilla Sandbox Options (Generator-Related)

| Option | Type | Default | Range | Purpose |
|--------|------|---------|-------|---------|
| `GeneratorFuelConsumption` | Double | 1.0 | 0-100 | Multiplier on fuel drain. 0 = no fuel used |
| `GeneratorSpawning` | Enum | varies | presets | Generator spawn frequency |
| `GeneratorTileRange` | Integer | 20 | 1-100 | Horizontal power radius |
| `GeneratorVerticalPower` | Integer | 3 | 1-15 | Vertical range in floors |

---

## Key Events

### Initialization (firing order)

| Event | Timing | Parameters | Use For |
|-------|--------|------------|---------|
| `OnInitGlobalModData` | Earliest after sandbox loads | `newGame (bool)` | Init persistent data. Earliest sandbox options are available |
| `OnGameBoot` | After game startup | none | Early setup. Server lua NOT yet loaded on clients |
| `OnGameStart` | When game begins loading | none | Apply sandbox options, initialize mod state |

### Periodic

| Event | Frequency | Parameters | Use For |
|-------|-----------|------------|---------|
| `OnTick` | Every game tick | `numberOfTicks` | High-frequency (use sparingly) |
| `EveryOneMinute` | Every in-game minute | none | Medium-frequency checks |
| `EveryTenMinutes` | Every 10 in-game minutes | none | Periodic maintenance |
| `EveryHours` | Every in-game hour | none | Low-frequency updates |
| `EveryDays` | Every in-game day | none | Daily maintenance |

### UI/Interaction

| Event | Trigger | Parameters | Use For |
|-------|---------|------------|---------|
| `OnFillWorldObjectContextMenu` | Right-click world object | `playerNum, context, worldobjects, test` | Custom context menus. Check `test` and return early if true |
| `OnObjectAdded` | Object placed in world | `isoObject` | Detect new generator placement |

### Multiplayer

| Event | Trigger | Parameters | Use For |
|-------|---------|------------|---------|
| `OnClientCommand` | Server receives client cmd | `module, command, playerObj, args` | Handle client requests on server |
| `OnServerCommand` | Client receives server cmd | `module, command, args` | Handle server responses on client |
| `OnConnected` | Client connects to server | none | Client-side MP init |

---

## Context Menu Pattern

```lua
local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end  -- Skip during UI build phase

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Find target object from worldobjects
    for _, obj in ipairs(worldobjects) do
        if obj and obj.getSquare then
            local sq = obj:getSquare()
            -- Check for generator, container, etc.
        end
    end

    -- Add options
    context:addOption("Menu Text", nil, function()
        -- Action here
        sendClientCommand("ModId", "Action", { x = x, y = y, z = z })
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
```

---

## B42 Breaking Changes

### From B41

| Area | B41 | B42 |
|------|-----|-----|
| Content folder | `media/` at mod root | `42/media/` under build folder |
| Sandbox options | Various formats | `VERSION = 1` required, dotted names |
| SandboxVars access | `SandboxVars.FlatName` | `SandboxVars.ModId.Option` (nested) |
| Generator activate | `activate()` / `deactivate()` | `setActivated(bool)` + `setSurroundingElectricity()` |
| mod.info location | Root only | Root only (do NOT put in 42/ subfolder) |
| Script .txt files | Old format | Changed format — manual review required |
| Saves | B41 format | NOT compatible with B41 saves |

### B42.8 Changes
- `GeneratorTileRange` sandbox option added (default 20, range 1-100)
- `GeneratorVerticalPower` sandbox option added (default 3, range 1-15)

### B42.12 Changes
- Explosion logic migrated from IsoGridSquare to IsoGenerator
- Fuel consumption rate changed (community fix mods appeared)

### B42.13 Changes (Major)
- **New namespace/registry system:** `ResourceLocation` identifiers and `Registry<T>` typed registries
- Mods can register entries in `media/registries.lua` (loaded before all other Lua/scripts)
- Refactored classes use type-safe objects instead of string identifiers
- Broke many existing mods — official migration guide: https://theindiestone.com/forums/index.php?/topic/88499-modding-migration-guide-4213/

---

## Multiplayer Considerations

- **All state changes MUST happen on server** — client sends commands, server executes
- **Always sync changes:** `sendObjectChange()` or `sync()` after modifying objects
- **Player validation:** Server receives `playerObj` — use for notifications and auth
- **Coordinate-based lookups:** Pass coordinates in commands, not object references
- **Avoid client-side state mutation:** UI/visual-only operations are safe on client

---

## Performance Guidelines

- **Radius search:** O((2r+1)^2) per call — keep radius reasonable (default 20 = 1,681 squares)
- **Avoid per-tick cluster searches:** Use event-driven approach, not EveryOneMinute
- **Cache when possible:** Generator lists don't change often
- **Minimize MP traffic:** Batch state syncs, don't sync unchanged values

---

## Lua Environment (Kahlua2)

PZ uses Kahlua2, a Lua 5.1 JVM implementation with limitations:

- **No coroutines** (co-routine support limited)
- **No debug library** (no debug.getinfo, etc.)
- **No os/io libraries** (sandboxed, use PZ API instead)
- **No require path manipulation** — PZ loads files by convention (client/server/shared dirs)
- **instanceof()** is a PZ global function, not standard Lua
- **isServer()** / **isClient()** — PZ globals for context detection
- **getCell()** — client-only, `getWorld():getCell()` — works on both but prefer on server

---

## Reference URLs

**Official:**
- JavaDocs IsoGenerator: https://projectzomboid.com/modding/zombie/iso/objects/IsoGenerator.html
- JavaDocs IsoObject: https://projectzomboid.com/modding/zombie/iso/IsoObject.html
- JavaDocs IsoGridSquare: https://projectzomboid.com/modding/zombie/iso/IsoGridSquare.html

**Wiki:**
- PZwiki Modding: https://pzwiki.net/wiki/Modding
- PZwiki Generator: https://pzwiki.net/wiki/Generator
- PZwiki Lua API: https://pzwiki.net/wiki/Lua_(API)
- PZwiki Lua Events: https://pzwiki.net/wiki/Lua_event
- PZwiki Mod Structure: https://pzwiki.net/wiki/Mod_structure
- PZwiki Registries: https://pzwiki.net/wiki/Registries
- PZwiki Sandbox Options: https://pzwiki.net/wiki/Sandbox_options

**Community:**
- PZEventDoc: https://github.com/demiurgeQuantified/PZEventDoc
- Vanilla Lua Source: https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua
- B42 Mod Template: https://github.com/LabX1/ProjectZomboid-Build42-ModTemplate
- Awesome B42 Resources: https://github.com/JBD-Mods/awesome-project-zomboid-build42-resources
- FWolfe Modding Guide: https://github.com/FWolfe/Zomboid-Modding-Guide
- PZ Libraries (IntelliSense): https://github.com/Konijima/PZ-Libraries

**Similar Mods (Workshop):**
- Ultimate Generator Overhaul (3478628177)
- Generator Tweaks - Power (3565393936)
- Multiple Generators (3150779947)
- Fix Generator Fuel Consumption (3574660562)
