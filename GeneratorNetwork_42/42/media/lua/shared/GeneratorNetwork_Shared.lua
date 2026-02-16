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
    -- v2.0 building commands
    BuildingOn      = "BuildingOn",
    BuildingOff     = "BuildingOff",
    RefuelBuilding  = "RefuelBuilding",
    BuildingResult  = "BuildingResult",
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

--- Activate or deactivate generators with building power support.
--- For activation: uses vanilla setActivated + setSurroundingElectricity + building power.
--- For deactivation: setActivated only, then refreshBuildingPower (avoids vanilla clearing bug).
--- Returns: changed, skippedUnconnected, failedStart
function GN.setGeneratorsActivated(playerObj, gens, flag, building)
    if not gens or #gens == 0 then
        _log("[POWER] setGeneratorsActivated: no generators")
        return 0, 0, 0
    end

    _log(string.format("[POWER] setGeneratorsActivated flag=%s gens=%d hasBuilding=%s",
        tostring(flag), #gens, tostring(building ~= nil)))

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
                    gen:setSurroundingElectricity()
                    changed = changed + 1
                end
            else
                -- Turn OFF
                if active then
                    _log(string.format("[POWER] deactivating gen at %d,%d,%d", x, y, z))
                    gen:setActivated(false)
                    -- Clear vanilla radius power. For building mode, refreshBuildingPower
                    -- will re-apply building power afterward if other gens are still active.
                    gen:setSurroundingElectricity()
                    changed = changed + 1
                end
            end
        end
    end

    -- After all state changes, refresh building power.
    if building then
        GN.refreshBuildingPower(building)
        GN.registerBuilding(building)
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
end

-- ========================================================================
-- Periodic maintenance (EveryOneMinute — server only)
-- ========================================================================

--- Called every in-game minute on server.
--- Re-powers managed buildings (self-heals chunk load/unload gaps).
local function _onEveryOneMinute()
    if not isServer() then return end

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
                GN.powerBuilding(building, true)
            else
                table.insert(toRemove, id)
            end
        else
            table.insert(toRemove, id)
        end
    end

    for _, id in ipairs(toRemove) do
        GN.ManagedBuildings[id] = nil
        _log(string.format("[MAINT] Unregistered building ID %s", tostring(id)))
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
