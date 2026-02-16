-- GeneratorNetwork_Shared.lua
-- Shared logic for Generator Network 0.9.0

if GeneratorNetwork and GeneratorNetwork.Initialized then
    return
end

GeneratorNetwork = GeneratorNetwork or {}
local GN = GeneratorNetwork

GN.ModId = "GeneratorNetwork"
GN.Version = "0.9.0"

GN.DEBUG = false
GN.ClusterRadius = 20

-- Command constants — single source of truth for client/server.
GN.Commands = {
    RefuelCluster = "RefuelCluster",
    ClusterOn     = "ClusterOn",
    ClusterOff    = "ClusterOff",
    ClusterResult = "ClusterResult",
}

local function _log(msg)
    if GN.DEBUG then
        print(string.format("[GeneratorNetwork %s] %s", tostring(GN.Version), tostring(msg)))
    end
end

GN.log = _log

local function _getCell()
    if isServer() then
        return getWorld():getCell()
    else
        return getCell()
    end
end

function GN.applySandboxOptions()
    if SandboxVars and SandboxVars.GeneratorNetwork then
        if SandboxVars.GeneratorNetwork.Debug ~= nil then
            GN.DEBUG = SandboxVars.GeneratorNetwork.Debug
        end
        if SandboxVars.GeneratorNetwork.Radius ~= nil then
            GN.ClusterRadius = SandboxVars.GeneratorNetwork.Radius
        end
    end
    _log(string.format("applySandboxOptions: DEBUG=%s radius=%d",
        tostring(GN.DEBUG), tonumber(GN.ClusterRadius or 0)))
end

-- Basic sanity check that we have a live IsoGenerator in the world.
local function _isValidGen(gen)
    if not gen then return false end
    if not instanceof(gen, "IsoGenerator") then return false end

    local sq = gen:getSquare()
    if not sq then return false end

    if gen.getObjectIndex and gen:getObjectIndex() == -1 then
        return false
    end

    return true
end

GN.isValidGen = _isValidGen

function GN.notifyPlayer(playerObj, msg)
    if not playerObj or not msg then return end
    if playerObj.Say then
        playerObj:Say(msg)
    end
end

function GN.getGeneratorsAround(x, y, z, radius)
    radius = radius or GN.ClusterRadius or 20
    local cell = _getCell()
    local gens = {}

    if not cell then
        _log("getGeneratorsAround: no cell available")
        return gens
    end

    _log(string.format("[CLUSTER] Searching at %d,%d,%d with radius %d", x, y, z, radius))

    for wx = x - radius, x + radius do
        for wy = y - radius, y + radius do
            local sq = cell:getGridSquare(wx, wy, z)
            if sq then
                local gen = sq:getGenerator()
                if _isValidGen(gen) then
                    table.insert(gens, gen)
                    if GN.DEBUG then
                        local fuel = gen:getFuel() or 0.0
                        local active = gen:isActivated()
                        local connected = gen:isConnected()
                        _log(string.format("[CLUSTER] Found generator at %d,%d,%d fuel=%.3f active=%s connected=%s",
                            wx, wy, z, fuel, tostring(active), tostring(connected)))
                    end
                end
            end
        end
    end

    _log(string.format("[CLUSTER] Search completed -> %d generators", #gens))
    return gens
end

-- MP-safe fuel sharing. Returns count and per-gen fuel for feedback.
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
        else
            _log("[FUEL] skipping invalid generator in candidate list")
        end
    end

    _log(string.format("[FUEL] distributeFuelEvenly: validGens=%d total=%.3f",
        #validGens, totalFuel))

    if #validGens == 0 or totalFuel <= 0.0 then
        _log("[FUEL] distributeFuelEvenly: nothing to distribute")
        return #validGens, 0.0
    end

    local per = totalFuel / #validGens
    _log(string.format("[FUEL] distributeFuelEvenly -> per-gen=%.3f", per))

    for _, gen in ipairs(validGens) do
        gen:setFuel(per)
        _log(string.format("[FUEL] set fuel on gen at %d,%d,%d to %.3f",
            gen:getX(), gen:getY(), gen:getZ(), per))

        if isServer() then
            gen:sendObjectChange("fuel")
        end
    end

    return #validGens, per
end

-- Cluster activation using setActivated() + setSurroundingElectricity(),
-- wrapped in our connection + fuel/condition checks.
-- Returns counts for feedback: activated, skippedUnconnected, failedStart.
function GN.setClusterActivated(playerObj, gens, flag)
    if not gens or #gens == 0 then
        _log("[POWER] setClusterActivated: no generators")
        return 0, 0, 0
    end

    _log(string.format("[POWER] setClusterActivated flag=%s gens=%d",
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

            _log(string.format("[POWER] considering gen at %d,%d,%d fuel=%.3f cond=%d active=%s connected=%s",
                x, y, z, fuel, cond, tostring(active), tostring(connected)))

            if flag then
                -- Turn cluster ON
                if not connected then
                    _log(string.format("[POWER] skipping unconnected gen at %d,%d,%d", x, y, z))
                    skippedUnconnected = skippedUnconnected + 1
                elseif fuel <= 0.0 or cond <= 0 then
                    _log(string.format("[POWER] gen at %d,%d,%d has no fuel/condition, calling failToStart()", x, y, z))
                    if gen.failToStart then
                        gen:failToStart()
                    end
                    failedStart = failedStart + 1
                else
                    if not active then
                        _log(string.format("[POWER] activating gen at %d,%d,%d", x, y, z))
                        gen:setActivated(true)
                        gen:setSurroundingElectricity()
                        changed = changed + 1
                    else
                        _log(string.format("[POWER] gen at %d,%d,%d already active, skipping", x, y, z))
                    end
                end
            else
                -- Turn cluster OFF
                if active then
                    _log(string.format("[POWER] deactivating gen at %d,%d,%d", x, y, z))
                    gen:setActivated(false)
                    gen:setSurroundingElectricity()
                    changed = changed + 1
                else
                    _log(string.format("[POWER] gen at %d,%d,%d already inactive, skipping", x, y, z))
                end
            end
        else
            _log("[POWER] skipping invalid generator in cluster")
        end
    end

    -- Notify player about unconnected generators with count
    if skippedUnconnected > 0 then
        local total = #gens
        GN.notifyPlayer(playerObj,
            string.format("%d of %d generators aren't connected. Use 'Connect Generator' on each first.",
                skippedUnconnected, total))
    end

    return changed, skippedUnconnected, failedStart
end

Events.OnGameStart.Add(function()
    GN.applySandboxOptions()
end)

GN.Initialized = true
_log("Shared core loaded")
