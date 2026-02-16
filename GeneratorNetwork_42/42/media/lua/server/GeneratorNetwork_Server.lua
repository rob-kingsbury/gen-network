-- GeneratorNetwork_Server.lua
-- Server-side command handler for Generator Network 2.0.0
-- Routes building power and radius fallback commands to shared logic.

require "GeneratorNetwork_Shared"

local GN = GeneratorNetwork
local CMD = GN.Commands

local function _log(msg)
    GN.log("[SV] " .. tostring(msg))
end

-- ------------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------------

--- Look up a valid generator at the given coordinates.
local function _getGenAt(x, y, z)
    local cell = getWorld():getCell()
    if not cell then return nil end
    local sq = cell:getGridSquare(x, y, z)
    if not sq then return nil end
    local gen = sq:getGenerator()
    if not GN.isValidGen(gen) then return nil end
    return gen
end

-- ------------------------------------------------------------------------
-- Building commands
-- ------------------------------------------------------------------------

local function _handleBuildingOnOff(playerObj, gen, x, y, z, flag)
    local building = GN.getBuildingForGen(gen)
    if not building then
        GN.notifyPlayer(playerObj, "Generator is not in a building.")
        return
    end

    local gens = GN.getGeneratorsInBuilding(building)
    GN.ensureGenInList(gens, gen)
    local changed, skipped, failed = GN.setGeneratorsActivated(playerObj, gens, flag, building)

    if changed > 0 then
        if flag then
            GN.notifyPlayer(playerObj,
                string.format("Building: %d generators activated.", changed))
        else
            GN.notifyPlayer(playerObj,
                string.format("Building: %d generators deactivated.", changed))
        end
    elseif changed == 0 and skipped == 0 and failed == 0 then
        GN.notifyPlayer(playerObj, "No generators to change.")
    end

    sendServerCommand(playerObj, GN.ModId, CMD.BuildingResult, {
        action = flag and CMD.BuildingOn or CMD.BuildingOff,
        changed = tostring(changed),
        skipped = tostring(skipped),
        failed = tostring(failed),
    })
end

local function _handleRefuelBuilding(playerObj, gen)
    local building = GN.getBuildingForGen(gen)
    if not building then
        GN.notifyPlayer(playerObj, "Generator is not in a building.")
        return
    end

    local gens = GN.getGeneratorsInBuilding(building)
    GN.ensureGenInList(gens, gen)
    local count, perFuel = GN.distributeFuelEvenly(gens)

    GN.notifyPlayer(playerObj,
        string.format("Building refueled: %d generators at %.1f%% each.", count, perFuel))

    sendServerCommand(playerObj, GN.ModId, CMD.BuildingResult, {
        action = CMD.RefuelBuilding,
        count = tostring(count),
        perFuel = tostring(perFuel),
    })
end

-- ------------------------------------------------------------------------
-- Radius fallback commands
-- ------------------------------------------------------------------------

local function _handleRadiusOnOff(playerObj, x, y, z, flag)
    local gens = GN.getGeneratorsAround(x, y, z, GN.ClusterRadius)
    local changed, skipped, failed = GN.setGeneratorsActivated(playerObj, gens, flag, nil)

    if changed > 0 then
        if flag then
            GN.notifyPlayer(playerObj,
                string.format("Cluster: %d generators activated.", changed))
        else
            GN.notifyPlayer(playerObj,
                string.format("Cluster: %d generators deactivated.", changed))
        end
    elseif changed == 0 and skipped == 0 and failed == 0 then
        GN.notifyPlayer(playerObj, "No generators to change.")
    end

    sendServerCommand(playerObj, GN.ModId, CMD.RadiusResult, {
        action = flag and CMD.RadiusOn or CMD.RadiusOff,
        changed = tostring(changed),
        skipped = tostring(skipped),
        failed = tostring(failed),
    })
end

local function _handleRefuelRadius(playerObj, x, y, z)
    local gens = GN.getGeneratorsAround(x, y, z, GN.ClusterRadius)
    local count, perFuel = GN.distributeFuelEvenly(gens)

    GN.notifyPlayer(playerObj,
        string.format("Cluster refueled: %d generators at %.1f%% each.", count, perFuel))

    sendServerCommand(playerObj, GN.ModId, CMD.RadiusResult, {
        action = CMD.RefuelRadius,
        count = tostring(count),
        perFuel = tostring(perFuel),
    })
end

-- ------------------------------------------------------------------------
-- Command router
-- ------------------------------------------------------------------------

local function onClientCommand(module, command, playerObj, args)
    if module ~= GN.ModId then return end

    if not args or not args.x or not args.y or not args.z then
        _log("onClientCommand: missing coordinates")
        return
    end

    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    local action = tostring(command or "none")

    _log(string.format("onClientCommand: %s at %d,%d,%d", action, x, y, z))

    -- Building commands require a valid generator at the target square.
    if action == CMD.BuildingOn or action == CMD.BuildingOff or action == CMD.RefuelBuilding then
        local gen = _getGenAt(x, y, z)
        if not gen then
            _log(string.format("onClientCommand: no valid generator at %d,%d,%d", x, y, z))
            GN.notifyPlayer(playerObj, "No generator found at that location.")
            return
        end

        if action == CMD.BuildingOn then
            _handleBuildingOnOff(playerObj, gen, x, y, z, true)
        elseif action == CMD.BuildingOff then
            _handleBuildingOnOff(playerObj, gen, x, y, z, false)
        elseif action == CMD.RefuelBuilding then
            _handleRefuelBuilding(playerObj, gen)
        end

    -- Radius fallback commands use area search.
    elseif action == CMD.RadiusOn then
        _handleRadiusOnOff(playerObj, x, y, z, true)
    elseif action == CMD.RadiusOff then
        _handleRadiusOnOff(playerObj, x, y, z, false)
    elseif action == CMD.RefuelRadius then
        _handleRefuelRadius(playerObj, x, y, z)

    else
        _log("onClientCommand: unknown action " .. tostring(action))
    end
end

Events.OnClientCommand.Add(onClientCommand)

_log("Server script loaded (v2.0.0)")
