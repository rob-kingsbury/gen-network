-- GeneratorNetwork_Shared.lua
-- Shared logic for Generator Network 2.0.0
-- Building-based power delivery with indoor safety and radius fallback.

if GeneratorNetwork and GeneratorNetwork.Initialized then
    return
end

GeneratorNetwork = GeneratorNetwork or {}
local GN = GeneratorNetwork

GN.ModId = "GeneratorNetwork"
GN.Version = "2.0.0"

GN.DEBUG = false
GN.ClusterRadius = 20
GN.TankCapacity = 500

-- Command constants — single source of truth for client/server.
GN.Commands = {
    -- v2.0 building commands (vanilla buildings)
    BuildingOn      = "BuildingOn",
    BuildingOff     = "BuildingOff",
    RefuelBuilding  = "RefuelBuilding",
    BuildingResult  = "BuildingResult",
    -- v2.0 structure commands (flood-fill detected, player-built)
    StructureOn     = "StructureOn",
    StructureOff    = "StructureOff",
    RefuelStructure = "RefuelStructure",
    StructureResult = "StructureResult",
    -- v1.0 radius fallback (same logic, different label)
    RadiusOn        = "RadiusOn",
    RadiusOff       = "RadiusOff",
    RefuelRadius    = "RefuelRadius",
    RadiusResult    = "RadiusResult",
}

-- Managed buildings: keyed by building ID, each entry tracks active generators.
-- { [buildingId] = { building = IsoBuilding, gens = { gen1, gen2, ... } } }
GN.ManagedBuildings = {}

-- Flag for initial power application after load.
GN._needsInitialPowerApply = false

-- ========================================================================
-- Logging
-- ========================================================================

local function _log(msg)
    if GN.DEBUG then
        print(string.format("[GeneratorNetwork %s] %s", tostring(GN.Version), tostring(msg)))
    end
end

GN.log = _log

-- ========================================================================
-- Cell access (client vs server)
-- ========================================================================

local function _getCell()
    if isServer() then
        return getWorld():getCell()
    else
        return getCell()
    end
end

-- ========================================================================
-- Sandbox options
-- ========================================================================

function GN.applySandboxOptions()
    if SandboxVars and SandboxVars.GeneratorNetwork then
        if SandboxVars.GeneratorNetwork.Debug ~= nil then
            GN.DEBUG = SandboxVars.GeneratorNetwork.Debug
        end
        if SandboxVars.GeneratorNetwork.Radius ~= nil then
            GN.ClusterRadius = SandboxVars.GeneratorNetwork.Radius
        end
        if SandboxVars.GeneratorNetwork.TankCapacity ~= nil then
            GN.TankCapacity = SandboxVars.GeneratorNetwork.TankCapacity
        end
    end
    _log(string.format("applySandboxOptions: DEBUG=%s radius=%d tankCapacity=%d",
        tostring(GN.DEBUG), tonumber(GN.ClusterRadius or 0), tonumber(GN.TankCapacity or 500)))
end

-- ========================================================================
-- Generator validation
-- ========================================================================

local function _isValidGen(gen)
    if not gen then return false end
    if not instanceof(gen, "IsoGenerator") then return false end
    local sq = gen:getSquare()
    if not sq then return false end
    if gen.getObjectIndex and gen:getObjectIndex() == -1 then return false end
    return true
end

GN.isValidGen = _isValidGen

-- ========================================================================
-- Player notifications
-- ========================================================================

function GN.notifyPlayer(playerObj, msg)
    if not playerObj or not msg then return end
    if playerObj.Say then
        playerObj:Say(msg)
    end
end

-- ========================================================================
-- Building detection
-- ========================================================================

--- Get the IsoBuilding for a generator. Checks the generator's own square first,
--- then adjacent squares (handles exterior wall placement).
--- Returns nil for outdoor or player-built structures.
function GN.getBuildingForGen(gen)
    if not _isValidGen(gen) then return nil end
    local sq = gen:getSquare()
    if not sq then return nil end

    -- Check generator's own square first.
    local building = sq:getBuilding()
    if building then return building end

    -- Check 8 adjacent squares (exterior wall fallback).
    local cell = _getCell()
    if not cell then return nil end
    local gx, gy, gz = sq:getX(), sq:getY(), sq:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local adj = cell:getGridSquare(gx + dx, gy + dy, gz)
                if adj then
                    local adjBuilding = adj:getBuilding()
                    if adjBuilding then
                        _log(string.format("[BUILDING] Found building via adjacent square at %d,%d,%d",
                            gx + dx, gy + dy, gz))
                        return adjBuilding
                    end
                end
            end
        end
    end

    _log(string.format("[BUILDING] No building found for gen at %d,%d,%d", gx, gy, gz))
    return nil
end

--- Get all grid squares belonging to a building by iterating its room definitions.
--- Handles multi-floor buildings.
function GN.getAllBuildingSquares(building)
    local squares = {}
    if not building then return squares end

    local def = building:getDef()
    if not def then
        _log("[BUILDING] Building has no BuildingDef")
        return squares
    end

    local rooms = def:getRooms()
    if not rooms then return squares end

    local cell = _getCell()
    if not cell then return squares end

    local roomCount = rooms:size()
    _log(string.format("[BUILDING] Iterating %d rooms", roomCount))

    for i = 0, roomCount - 1 do
        local roomDef = rooms:get(i)
        if roomDef then
            local rz = roomDef:getZ()
            local rects = roomDef:getRects()
            if rects then
                for j = 0, rects:size() - 1 do
                    local rect = rects:get(j)
                    if rect then
                        local rx = rect:getX()
                        local ry = rect:getY()
                        local rw = rect:getW()
                        local rh = rect:getH()
                        for wx = rx, rx + rw - 1 do
                            for wy = ry, ry + rh - 1 do
                                local sq = cell:getGridSquare(wx, wy, rz)
                                if sq then
                                    table.insert(squares, sq)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    _log(string.format("[BUILDING] Collected %d squares from building ID %d",
        #squares, building:getID() or -1))
    return squares
end

--- Find all valid generators whose square belongs to the given building.
function GN.getGeneratorsInBuilding(building)
    if not building then return {} end

    local gens = {}
    local squares = GN.getAllBuildingSquares(building)

    for _, sq in ipairs(squares) do
        local gen = sq:getGenerator()
        if _isValidGen(gen) then
            table.insert(gens, gen)
        end
    end

    _log(string.format("[BUILDING] Found %d generators in building", #gens))
    return gens
end

--- Ensure a generator is included in a list (for exterior wall generators).
--- Returns the list with gen added if not already present.
function GN.ensureGenInList(gens, gen)
    if not _isValidGen(gen) then return gens end
    local gx, gy, gz = gen:getX(), gen:getY(), gen:getZ()
    for _, existing in ipairs(gens) do
        if existing:getX() == gx and existing:getY() == gy and existing:getZ() == gz then
            return gens
        end
    end
    table.insert(gens, gen)
    return gens
end

-- ========================================================================
-- Wall detection (for flood-fill)
-- ========================================================================

GN.MAX_FLOOD_FILL = 1000

--- Check if a square has a wall blocking passage in a given direction.
--- Doors are passable (not blocking). Windows and solid walls block.
--- PZ isometric model: walls sit on N and W edges of a square.
--- @param sq IsoGridSquare to check
--- @param edge string "N" or "W" — which edge to check on this square
--- @return boolean true if a non-door wall blocks this edge
local function _hasWallOnEdge(sq, edge)
    if not sq then return false end
    local objects = sq:getObjects()
    if not objects then return false end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            -- Doors are passable — skip them
            if instanceof(obj, "IsoDoor") then
                -- check if door is on the correct edge
                local sprite = obj:getSprite()
                if sprite then
                    local props = sprite:getProperties()
                    if props then
                        if edge == "N" and props:Is(IsoFlagType.WallN) then return false end
                        if edge == "W" and props:Is(IsoFlagType.WallW) then return false end
                    end
                end
            else
                local sprite = obj:getSprite()
                if sprite then
                    local props = sprite:getProperties()
                    if props then
                        if edge == "N" and props:Is(IsoFlagType.WallN) then return true end
                        if edge == "W" and props:Is(IsoFlagType.WallW) then return true end
                    end
                end
            end
        end
    end
    return false
end

--- Check if movement from one square to an adjacent square is blocked by a wall.
--- @param fromSq IsoGridSquare source square
--- @param toSq IsoGridSquare target square
--- @param dx int x offset (-1, 0, or 1)
--- @param dy int y offset (-1, 0, or 1)
--- @return boolean true if passage is blocked
local function _isWallBlocking(fromSq, toSq, dx, dy)
    if dy == -1 then
        -- Moving NORTH: check fromSq's north edge
        return _hasWallOnEdge(fromSq, "N")
    elseif dy == 1 then
        -- Moving SOUTH: check toSq's north edge
        return _hasWallOnEdge(toSq, "N")
    elseif dx == -1 then
        -- Moving WEST: check fromSq's west edge
        return _hasWallOnEdge(fromSq, "W")
    elseif dx == 1 then
        -- Moving EAST: check toSq's west edge
        return _hasWallOnEdge(toSq, "W")
    end
    return false
end

-- ========================================================================
-- Flood-fill structure detection
-- ========================================================================

--- BFS flood-fill from a starting square, bounded by walls.
--- Doors allow passage, walls and windows block.
--- @param startSq IsoGridSquare to start from
--- @param maxSquares int safety cap (default GN.MAX_FLOOD_FILL)
--- @return table list of IsoGridSquare in the enclosed area, or nil if cap hit
function GN.floodFillFrom(startSq, maxSquares)
    maxSquares = maxSquares or GN.MAX_FLOOD_FILL
    if not startSq then return nil end

    local cell = _getCell()
    if not cell then return nil end

    local startX, startY, startZ = startSq:getX(), startSq:getY(), startSq:getZ()
    local visited = {}
    local result = {}

    -- BFS queue (simple table-based FIFO)
    local queue = {}
    local qHead = 1
    local qTail = 1

    local startKey = string.format("%d,%d,%d", startX, startY, startZ)
    queue[qTail] = startSq
    qTail = qTail + 1
    visited[startKey] = true

    local directions = { {0, -1}, {0, 1}, {-1, 0}, {1, 0} } -- N, S, W, E

    while qHead < qTail do
        local sq = queue[qHead]
        qHead = qHead + 1

        table.insert(result, sq)

        if #result >= maxSquares then
            _log(string.format("[FLOOD] Cap hit (%d squares) — area not enclosed", maxSquares))
            return nil
        end

        local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()

        -- Expand horizontally (same floor)
        for _, dir in ipairs(directions) do
            local dx, dy = dir[1], dir[2]
            local nx, ny = sx + dx, sy + dy
            local key = string.format("%d,%d,%d", nx, ny, sz)

            if not visited[key] then
                local neighbor = cell:getGridSquare(nx, ny, sz)
                if neighbor then
                    if not _isWallBlocking(sq, neighbor, dx, dy) then
                        visited[key] = true
                        queue[qTail] = neighbor
                        qTail = qTail + 1
                    end
                end
            end
        end

        -- Expand vertically via stairs (multi-floor support).
        -- Vanilla has HasStairsWest/HasStairsNorth; mods may add East/South variants.
        local hasStairs = false
        if sq.HasStairsWest and sq:HasStairsWest() then hasStairs = true end
        if sq.HasStairsNorth and sq:HasStairsNorth() then hasStairs = true end
        if sq.HasStairsEast and sq:HasStairsEast() then hasStairs = true end
        if sq.HasStairsSouth and sq:HasStairsSouth() then hasStairs = true end

        if hasStairs then
            -- Add floor above
            local aboveKey = string.format("%d,%d,%d", sx, sy, sz + 1)
            if not visited[aboveKey] then
                local above = cell:getGridSquare(sx, sy, sz + 1)
                if above then
                    visited[aboveKey] = true
                    queue[qTail] = above
                    qTail = qTail + 1
                end
            end
            -- Add floor below (in case we enter from the top of stairs)
            local belowKey = string.format("%d,%d,%d", sx, sy, sz - 1)
            if sz > 0 and not visited[belowKey] then
                local below = cell:getGridSquare(sx, sy, sz - 1)
                if below then
                    visited[belowKey] = true
                    queue[qTail] = below
                    qTail = qTail + 1
                end
            end
        end
    end

    _log(string.format("[FLOOD] Fill from %d,%d,%d found %d squares",
        startX, startY, startZ, #result))
    return result
end

--- Find all valid generators within a set of flood-filled squares.
function GN.getGeneratorsInSquares(squares)
    if not squares then return {} end
    local gens = {}
    for _, sq in ipairs(squares) do
        local gen = sq:getGenerator()
        if _isValidGen(gen) then
            table.insert(gens, gen)
        end
    end
    return gens
end

-- ========================================================================
-- Building power delivery
-- ========================================================================

--- Set electricity on all squares in a building.
--- When turning off with force=false (default), checks for other active generators first.
--- Use force=true to bypass the active generator check.
function GN.powerBuilding(building, flag, force)
    if not building then return 0 end

    if not flag and not force then
        -- Before clearing power, check if other active generators exist in this building.
        local gens = GN.getGeneratorsInBuilding(building)
        for _, gen in ipairs(gens) do
            if _isValidGen(gen) and gen:isActivated() then
                _log("[POWER] Building still has active generator, skipping power clear")
                return 0
            end
        end
    end

    local squares = GN.getAllBuildingSquares(building)
    local count = 0

    for _, sq in ipairs(squares) do
        sq:setHaveElectricity(flag)
        count = count + 1
    end

    _log(string.format("[POWER] powerBuilding flag=%s squares=%d buildingID=%d",
        tostring(flag), count, building:getID() or -1))
    return count
end

--- Re-apply power for a building after a generator state change.
--- If any generator is still active, power stays on. Otherwise, force clear.
function GN.refreshBuildingPower(building)
    if not building then return end

    local gens = GN.getGeneratorsInBuilding(building)
    local hasActive = false

    for _, gen in ipairs(gens) do
        if _isValidGen(gen) and gen:isActivated() then
            hasActive = true
            break
        end
    end

    if hasActive then
        GN.powerBuilding(building, true)
    else
        GN.powerBuilding(building, false, true)
    end
end

--- Register a building as managed by our system.
--- Caches the generator list so OnTick can avoid expensive rescans.
function GN.registerBuilding(building)
    if not building then return end
    local id = building:getID()
    if not id then return end

    local gens = GN.getGeneratorsInBuilding(building)
    GN.ManagedBuildings[id] = { building = building, gens = gens }
    _log(string.format("[BUILDING] Registered building ID %d with %d cached generators", id, #gens))
end

--- Unregister a building if it no longer has any managed generators.
function GN.unregisterBuilding(building)
    if not building then return end
    local id = building:getID()
    if not id then return end

    local gens = GN.getGeneratorsInBuilding(building)
    if #gens == 0 then
        GN.ManagedBuildings[id] = nil
        _log(string.format("[BUILDING] Unregistered building ID %d (no generators)", id))
    end
end

--- Force-cleanup all managed buildings that no longer have active generators.
--- Clears electricity and unregisters them. Called immediately from command handlers
--- so stale buildings don't linger until the next EveryOneMinute cycle.
function GN.cleanupStaleBuildings()
    local toRemove = {}
    for id, entry in pairs(GN.ManagedBuildings) do
        local building = entry.building
        if building then
            local gens = GN.getGeneratorsInBuilding(building)
            entry.gens = gens
            local hasActive = false
            for _, gen in ipairs(gens) do
                if _isValidGen(gen) and gen:isActivated() then
                    hasActive = true
                    break
                end
            end
            if not hasActive then
                GN.powerBuilding(building, false, true)
                table.insert(toRemove, id)
            end
        else
            table.insert(toRemove, id)
        end
    end
    for _, id in ipairs(toRemove) do
        GN.ManagedBuildings[id] = nil
        _log(string.format("[CLEANUP] Removed stale building ID %s", tostring(id)))
    end
end

-- ========================================================================
-- Structure power delivery (flood-fill based, for player-built structures)
-- ========================================================================

-- Managed structures: keyed by "x,y,z" of generator.
-- { ["x,y,z"] = { squares = {sq1, sq2, ...}, gens = {gen1, ...} } }
GN.ManagedStructures = {}

--- Set electricity on all squares discovered by flood-fill.
--- When turning off with force=false (default), checks for other active generators first.
function GN.powerStructure(squares, flag, force)
    if not squares or #squares == 0 then return 0 end

    if not flag and not force then
        local gens = GN.getGeneratorsInSquares(squares)
        for _, gen in ipairs(gens) do
            if _isValidGen(gen) and gen:isActivated() then
                _log("[POWER] Structure still has active generator, skipping power clear")
                return 0
            end
        end
    end

    local count = 0
    for _, sq in ipairs(squares) do
        sq:setHaveElectricity(flag)
        count = count + 1
    end

    _log(string.format("[POWER] powerStructure flag=%s squares=%d", tostring(flag), count))
    return count
end

--- Re-apply power for a flood-filled structure.
--- If any generator is still active, power stays on. Otherwise, force clear.
function GN.refreshStructurePower(genKey)
    local entry = GN.ManagedStructures[genKey]
    if not entry then return end

    -- Re-flood-fill to update cached squares (walls may have changed).
    local cell = _getCell()
    if not cell then return end
    local parts = {}
    for part in string.gmatch(genKey, "[^,]+") do
        table.insert(parts, tonumber(part))
    end
    if #parts < 3 then return end
    local sq = cell:getGridSquare(parts[1], parts[2], parts[3])
    if not sq then return end

    local squares = GN.floodFillFrom(sq)
    if not squares then
        -- Area no longer enclosed, remove from managed.
        GN.ManagedStructures[genKey] = nil
        _log(string.format("[STRUCT] Removed %s — no longer enclosed", genKey))
        return
    end

    entry.squares = squares
    entry.gens = GN.getGeneratorsInSquares(squares)

    local hasActive = false
    for _, gen in ipairs(entry.gens) do
        if _isValidGen(gen) and gen:isActivated() then
            hasActive = true
            break
        end
    end

    if hasActive then
        GN.containPower(squares, entry.gens)
    else
        GN.powerStructure(squares, false, true)
        GN.ManagedStructures[genKey] = nil
        _log(string.format("[STRUCT] Unregistered %s — no active generators", genKey))
    end
end

--- Register a flood-filled structure as managed.
--- Also caches any vanilla IsoBuilding refs that overlap with the structure's squares
--- (needed for CO suppression — Java sets toxic on these buildings).
function GN.registerStructure(genSq, squares)
    if not genSq or not squares then return end
    local key = string.format("%d,%d,%d", genSq:getX(), genSq:getY(), genSq:getZ())
    local gens = GN.getGeneratorsInSquares(squares)

    -- Scan all structure squares for overlapping vanilla buildings.
    local buildings = {}
    local seenIds = {}
    for _, sq in ipairs(squares) do
        local b = sq:getBuilding()
        if b then
            local id = b:getID()
            if id and not seenIds[id] then
                seenIds[id] = true
                table.insert(buildings, b)
            end
        end
    end

    GN.ManagedStructures[key] = { squares = squares, gens = gens, buildings = buildings }
    _log(string.format("[STRUCT] Registered structure at %s with %d squares, %d gens, %d overlapping buildings",
        key, #squares, #gens, #buildings))
end

-- ========================================================================
-- Power containment (scrub leaked vanilla radius power)
-- ========================================================================

--- Build a hash set of "x,y,z" keys from a list of squares for O(1) lookup.
local function _buildSquareKeySet(squares)
    local keys = {}
    for _, sq in ipairs(squares) do
        keys[string.format("%d,%d,%d", sq:getX(), sq:getY(), sq:getZ())] = true
    end
    return keys
end

--- Clear electricity from squares within a generator's vanilla radius that
--- are outside the protected set. Counteracts Java's internal
--- setSurroundingElectricity() which fires inside setActivated() and on
--- chunk load events.
--- Also attempts B42.13+ chunk-level deregistration for hasGridPower() containment.
--- @param gens table List of generators to scrub around
--- @param protectedKeys table Hash set of "x,y,z" keys that should keep power
function GN.scrubLeakedPower(gens, protectedKeys)
    if not gens or #gens == 0 or not protectedKeys then return end

    local cell = _getCell()
    if not cell then return end

    -- Use vanilla sandbox options for radius.
    local hRadius = SandboxVars and SandboxVars.GeneratorTileRange or 20
    local vRadius = SandboxVars and SandboxVars.GeneratorVerticalPower or 3
    local scrubbed = 0

    for _, gen in ipairs(gens) do
        if _isValidGen(gen) and gen:isActivated() then
            local gx, gy, gz = gen:getX(), gen:getY(), gen:getZ()

            for wz = gz - vRadius, gz + vRadius do
                for wx = gx - hRadius, gx + hRadius do
                    for wy = gy - hRadius, gy + hRadius do
                        local key = string.format("%d,%d,%d", wx, wy, wz)
                        if not protectedKeys[key] then
                            local sq2 = cell:getGridSquare(wx, wy, wz)
                            if sq2 and sq2:haveElectricity() then
                                sq2:setHaveElectricity(false)
                                scrubbed = scrubbed + 1
                            end
                        end
                    end
                end
            end

            -- B42.13+ chunk deregistration: prevents hasGridPower() from
            -- reporting power outside the building/structure.
            local genSq = gen:getSquare()
            if genSq then
                local chunk = genSq:getChunk()
                if chunk and chunk.removeGeneratorPos then
                    pcall(function()
                        chunk:removeGeneratorPos(gx, gy, gz)
                    end)
                end
            end
        end
    end

    if scrubbed > 0 then
        _log(string.format("[SCRUB] Cleared %d leaked power squares", scrubbed))
    end
end

--- Power a set of squares and scrub leaked power beyond them.
--- Combines setHaveElectricity(true) on protected squares with scrubbing
--- the vanilla radius outside those squares.
--- @param squares table List of IsoGridSquare to power
--- @param gens table List of generators (for radius scrub)
function GN.containPower(squares, gens)
    if not squares or #squares == 0 or not gens then return end

    local protectedKeys = {}
    for _, sq in ipairs(squares) do
        sq:setHaveElectricity(true)
        protectedKeys[string.format("%d,%d,%d", sq:getX(), sq:getY(), sq:getZ())] = true
    end

    GN.scrubLeakedPower(gens, protectedKeys)
    _log(string.format("[POWER] containPower: %d protected squares, %d gens", #squares, #gens))
end

-- ========================================================================
-- Radius-based search (fallback for non-building generators)
-- ========================================================================

function GN.getGeneratorsAround(x, y, z, radius)
    radius = radius or GN.ClusterRadius or 20
    local cell = _getCell()
    local gens = {}

    if not cell then
        _log("getGeneratorsAround: no cell available")
        return gens
    end

    _log(string.format("[RADIUS] Searching at %d,%d,%d with radius %d", x, y, z, radius))

    for wx = x - radius, x + radius do
        for wy = y - radius, y + radius do
            local sq = cell:getGridSquare(wx, wy, z)
            if sq then
                local gen = sq:getGenerator()
                if _isValidGen(gen) then
                    table.insert(gens, gen)
                end
            end
        end
    end

    _log(string.format("[RADIUS] Search completed -> %d generators", #gens))
    return gens
end

-- ========================================================================
-- Fuel distribution (works for both building and radius groupings)
-- ========================================================================

function GN.distributeFuelEvenly(gens)
    if not gens or #gens == 0 then
        _log("[FUEL] distributeFuelEvenly: no generators")
        return 0, 0.0
    end

    local validGens = {}
    local totalFuel = 0.0

    for _, gen in ipairs(gens) do
        if _isValidGen(gen) then
            local f = gen:getFuel() or 0.0
            table.insert(validGens, gen)
            totalFuel = totalFuel + f
            _log(string.format("[FUEL] candidate gen at %d,%d,%d fuel=%.3f",
                gen:getX(), gen:getY(), gen:getZ(), f))
        end
    end

    if #validGens == 0 or totalFuel <= 0.0 then
        _log("[FUEL] distributeFuelEvenly: nothing to distribute")
        return #validGens, 0.0
    end

    local per = totalFuel / #validGens
    _log(string.format("[FUEL] distributeFuelEvenly -> per-gen=%.3f", per))

    for _, gen in ipairs(validGens) do
        gen:setFuel(per)
        if isServer() then
            gen:sendObjectChange("fuel")
        end
    end

    return #validGens, per
end

-- ========================================================================
-- Generator activation (building-aware)
-- ========================================================================

--- Activate or deactivate generators. Power management (building containment,
--- radius scrub) is handled by the caller after this returns.
--- Note: Java's setActivated() internally calls setSurroundingElectricity(),
--- so explicit calls here are unnecessary. Callers use containPower() or
--- refreshBuildingPower() to manage power boundaries.
--- Returns: changed, skippedUnconnected, failedStart
function GN.setGeneratorsActivated(playerObj, gens, flag)
    if not gens or #gens == 0 then
        _log("[POWER] setGeneratorsActivated: no generators")
        return 0, 0, 0
    end

    _log(string.format("[POWER] setGeneratorsActivated flag=%s gens=%d",
        tostring(flag), #gens))

    local changed = 0
    local skippedUnconnected = 0
    local failedStart = 0

    for _, gen in ipairs(gens) do
        if _isValidGen(gen) then
            local x, y, z = gen:getX(), gen:getY(), gen:getZ()
            local fuel = gen:getFuel() or 0.0
            local cond = gen.getCondition and gen:getCondition() or 100
            local connected = gen.isConnected and gen:isConnected() or false
            local active = gen.isActivated and gen:isActivated() or false

            if flag then
                -- Turn ON
                if not connected then
                    skippedUnconnected = skippedUnconnected + 1
                elseif fuel <= 0.0 or cond <= 0 then
                    if gen.failToStart then gen:failToStart() end
                    failedStart = failedStart + 1
                elseif not active then
                    _log(string.format("[POWER] activating gen at %d,%d,%d", x, y, z))
                    gen:setActivated(true)
                    -- Java internally calls setSurroundingElectricity().
                    -- Caller handles power containment (scrub) afterward.
                    changed = changed + 1
                end
            else
                -- Turn OFF
                if active then
                    _log(string.format("[POWER] deactivating gen at %d,%d,%d", x, y, z))
                    gen:setActivated(false)
                    -- Java internally calls setSurroundingElectricity() to clear radius.
                    changed = changed + 1
                end
            end
        end
    end

    -- Notify about unconnected generators.
    if skippedUnconnected > 0 then
        GN.notifyPlayer(playerObj,
            string.format("%d of %d generators aren't connected. Use 'Connect Generator' on each first.",
                skippedUnconnected, #gens))
    end

    return changed, skippedUnconnected, failedStart
end

-- ========================================================================
-- CO fume suppression (OnTick — matches Java update frequency)
-- ========================================================================

--- Called every game tick. Clears toxic flag on buildings with active managed generators.
--- This fights the Java IsoGenerator.update() which sets toxic=true every tick.
--- Uses cached generator list from registerBuilding() to avoid expensive building scans.
local function _onTick()
    -- Suppress CO for managed buildings (vanilla IsoBuilding).
    for _, entry in pairs(GN.ManagedBuildings) do
        local building = entry.building
        if building and building:isToxic() then
            local gens = entry.gens
            if gens then
                for _, gen in ipairs(gens) do
                    if _isValidGen(gen) and gen:isActivated() then
                        local sq = gen:getSquare()
                        if sq and not sq:isOutside() then
                            building:setToxic(false)
                            break
                        end
                    end
                end
            end
        end
    end

    -- Suppress CO for managed structures (player-built).
    -- Uses cached building refs from registerStructure — covers all vanilla buildings
    -- whose squares overlap with the flood-filled area.
    for _, entry in pairs(GN.ManagedStructures) do
        if entry.buildings then
            for _, building in ipairs(entry.buildings) do
                if building:isToxic() then
                    building:setToxic(false)
                end
            end
        end
    end
end

-- ========================================================================
-- Periodic maintenance (EveryOneMinute — server only)
-- ========================================================================

--- Called every in-game minute on server.
--- Re-powers managed buildings (self-heals chunk load/unload gaps).
local function _onEveryOneMinute()
    if isClient() then return end

    -- Collect IDs to remove after iteration (mutating during pairs() is undefined in Lua 5.1).
    local toRemove = {}

    for id, entry in pairs(GN.ManagedBuildings) do
        local building = entry.building
        if building then
            -- Refresh cached generator list.
            local gens = GN.getGeneratorsInBuilding(building)
            entry.gens = gens
            local hasActive = false
            for _, gen in ipairs(gens) do
                if _isValidGen(gen) and gen:isActivated() then
                    hasActive = true
                    break
                end
            end
            if hasActive then
                GN.containPower(GN.getAllBuildingSquares(building), gens)
            else
                table.insert(toRemove, id)
            end
        else
            table.insert(toRemove, id)
        end
    end

    for _, id in ipairs(toRemove) do
        local entry = GN.ManagedBuildings[id]
        if entry and entry.building then
            GN.powerBuilding(entry.building, false, true)
            _log(string.format("[MAINT] Cleared power for building ID %s", tostring(id)))
        end
        GN.ManagedBuildings[id] = nil
        _log(string.format("[MAINT] Unregistered building ID %s", tostring(id)))
    end

    -- Maintain managed structures (flood-fill based).
    local structToRemove = {}
    for key, _ in pairs(GN.ManagedStructures) do
        GN.refreshStructurePower(key)
        if not GN.ManagedStructures[key] then
            table.insert(structToRemove, key)
        end
    end
    for _, key in ipairs(structToRemove) do
        GN.ManagedStructures[key] = nil
    end

    -- Initial power application after load.
    if GN._needsInitialPowerApply then
        GN._needsInitialPowerApply = false
        _log("[MAINT] Initial power application after load completed")
    end
end

-- ========================================================================
-- Initialization
-- ========================================================================

Events.OnGameStart.Add(function()
    GN.applySandboxOptions()
    GN._needsInitialPowerApply = true
    _log("OnGameStart: sandbox options applied, initial power apply scheduled")
end)

-- OnTick: CO fume suppression — must run on both client and server to prevent damage.
Events.OnTick.Add(_onTick)

-- EveryOneMinute: building power maintenance — server only.
Events.EveryOneMinute.Add(_onEveryOneMinute)

GN.Initialized = true
_log("Shared core loaded (v2.0.0)")
