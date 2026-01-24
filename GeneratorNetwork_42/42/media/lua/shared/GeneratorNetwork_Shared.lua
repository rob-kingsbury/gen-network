-- GeneratorNetwork_Shared.lua
-- Shared logic for Generator Network 0.8.8
-- Based on 0.8.7 behaviour with improved fuel syncing and vanilla activate/deactivate,
-- plus extra debug logging.

if GeneratorNetwork and GeneratorNetwork.Initialized then
    return
end

GeneratorNetwork = GeneratorNetwork or {}
local GN = GeneratorNetwork

GN.ModId = "GeneratorNetwork"
GN.Version = "0.8.8"

GN.DEBUG = true
GN.ClusterRadius = 20

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

-- Improved, MP-safe fuel sharing based on valid generator list.
function GN.distributeFuelEvenly(gens)
    if not gens or #gens == 0 then
        _log("[FUEL] distributeFuelEvenly: no generators")
        return
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
        return
    end

    local per = totalFuel / #validGens
    _log(string.format("[FUEL] distributeFuelEvenly -> per-gen=%.3f", per))

    for _, gen in ipairs(validGens) do
        gen:setFuel(per)
        _log(string.format("[FUEL] set fuel on gen at %d,%d,%d to %.3f",
            gen:getX(), gen:getY(), gen:getZ(), per))

        if isServer() then
            -- MP-safe: explicitly sync fuel changes to clients.
            gen:sendObjectChange("fuel")
        end
    end
end

-- Cluster activation using setActivated() + setSurroundingElectricity(),
-- wrapped in our connection + fuel/condition checks.
function GN.setClusterActivated(playerObj, gens, flag)
    if not gens or #gens == 0 then
        _log("[POWER] setClusterActivated: no generators")
        return
    end

    _log(string.format("[POWER] setClusterActivated flag=%s gens=%d",
        tostring(flag), #gens))

    local warnedUnconnected = false

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
                    if not warnedUnconnected then
                        GN.notifyPlayer(playerObj, "Some generators aren't connected. Use 'Connect Generator' first.")
                        warnedUnconnected = true
                    end
                elseif fuel <= 0.0 or cond <= 0 then
                    _log(string.format("[POWER] gen at %d,%d,%d has no fuel/condition, calling failToStart()", x, y, z))
                    if gen.failToStart then
                        gen:failToStart()
                    end
                else
                    if not active then
                        _log(string.format("[POWER] activating gen at %d,%d,%d", x, y, z))
                        gen:setActivated(true)
                        gen:setSurroundingElectricity()
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
                else
                    _log(string.format("[POWER] gen at %d,%d,%d already inactive, skipping", x, y, z))
                end
            end
        else
            _log("[POWER] skipping invalid generator in cluster")
        end
    end
end

Events.OnGameStart.Add(function()
    GN.applySandboxOptions()
end)

GN.Initialized = true
_log("Shared core loaded")
