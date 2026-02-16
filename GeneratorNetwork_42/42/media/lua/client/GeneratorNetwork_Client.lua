-- GeneratorNetwork_Client.lua
-- Client-side context menu + command sender for Generator Network 2.0.0
-- Building-aware: detects building vs outdoor placement, adapts menu and coverage.

require "GeneratorNetwork_Shared"

local GN = GeneratorNetwork
local CMD = GN.Commands

local function _log(msg)
    GN.log("[CL] " .. tostring(msg))
end

-- ------------------------------------------------------------------------
-- Coverage highlighting (visual only, client-side)
-- ------------------------------------------------------------------------

GN.HighlightSquares = GN.HighlightSquares or {}

function GN.clearCoverageHighlights()
    if not GN.HighlightSquares then return end
    for _, sq in ipairs(GN.HighlightSquares) do
        if sq then
            local floor = sq:getFloor()
            if floor then
                floor:setHighlighted(false)
            end
        end
    end
    GN.HighlightSquares = {}
    _log("[COVERAGE] cleared highlights")
end

--- Highlight all squares belonging to a building.
function GN.showBuildingCoverage(building)
    if not building then return end

    GN.clearCoverageHighlights()

    local squares = GN.getAllBuildingSquares(building)
    if #squares == 0 then
        GN.notifyPlayer(getSpecificPlayer(0), "No building squares found.")
        return
    end

    for _, sq in ipairs(squares) do
        local floor = sq:getFloor()
        if floor then
            floor:setHighlighted(true)
            table.insert(GN.HighlightSquares, sq)
        end
    end

    _log(string.format("[COVERAGE] highlighted %d building squares", #GN.HighlightSquares))
end

--- Highlight radius coverage around all generators in a cluster (v1.0 fallback).
function GN.showRadiusCoverage(sq)
    if not sq then return end

    local cell = getCell()
    if not cell then
        _log("[COVERAGE] no cell")
        return
    end

    GN.clearCoverageHighlights()

    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local radius = GN.ClusterRadius or 20

    _log(string.format("[COVERAGE] radius coverage from %d,%d,%d radius=%d", x, y, z, radius))

    local gens = GN.getGeneratorsAround(x, y, z, radius)
    if #gens == 0 then
        GN.notifyPlayer(getSpecificPlayer(0), "No generators found in this cluster.")
        return
    end

    for _, gen in ipairs(gens) do
        if GN.isValidGen(gen) then
            local gx, gy, gz = gen:getX(), gen:getY(), gen:getZ()
            for wx = gx - radius, gx + radius do
                for wy = gy - radius, gy + radius do
                    local sq2 = cell:getGridSquare(wx, wy, gz)
                    if sq2 then
                        local floor = sq2:getFloor()
                        if floor then
                            floor:setHighlighted(true)
                            table.insert(GN.HighlightSquares, sq2)
                        end
                    end
                end
            end
        end
    end

    _log(string.format("[COVERAGE] highlighted %d radius squares", #GN.HighlightSquares))
end

-- ------------------------------------------------------------------------
-- Context menu
-- ------------------------------------------------------------------------

local function getGeneratorFromWorldObjects(worldobjects)
    if not worldobjects then return nil, nil end

    for _, obj in ipairs(worldobjects) do
        if obj and obj.getSquare then
            local sq = obj:getSquare()
            if sq then
                local gen = sq:getGenerator()
                if gen then
                    return gen, sq
                end
            end
        end
    end

    return nil, nil
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local gen, sq = getGeneratorFromWorldObjects(worldobjects)

    -- Clear coverage when opening a generator context menu.
    if gen then
        GN.clearCoverageHighlights()
    end

    if not gen or not sq then return end

    local x, y, z = sq:getX(), sq:getY(), sq:getZ()

    local function send(action)
        _log(string.format("send %s at %d,%d,%d", tostring(action), x, y, z))
        sendClientCommand(GN.ModId, action, { x = x, y = y, z = z })
    end

    -- Detect building vs radius mode.
    local building = GN.getBuildingForGen(gen)

    if building then
        -- Building mode: power the entire building through wiring.
        context:addOption("Turn Building On", nil, function()
            send(CMD.BuildingOn)
        end)

        context:addOption("Turn Building Off", nil, function()
            send(CMD.BuildingOff)
        end)

        context:addOption("Refuel Building Generators", nil, function()
            send(CMD.RefuelBuilding)
        end)

        context:addOption("Show Building Coverage", nil, function()
            GN.showBuildingCoverage(building)
        end)
    else
        -- Radius fallback: v1.0 cluster behavior for outdoor/player-built placement.
        context:addOption("Turn Cluster On", nil, function()
            send(CMD.RadiusOn)
        end)

        context:addOption("Turn Cluster Off", nil, function()
            send(CMD.RadiusOff)
        end)

        context:addOption("Refuel Cluster", nil, function()
            send(CMD.RefuelRadius)
        end)

        context:addOption("Show Cluster Coverage", nil, function()
            GN.showRadiusCoverage(sq)
        end)
    end

    context:addOption("Clear Coverage", nil, function()
        GN.clearCoverageHighlights()
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- ------------------------------------------------------------------------
-- Server response handler
-- ------------------------------------------------------------------------

local function onServerCommand(module, command, args)
    if module ~= GN.ModId then return end

    if command == CMD.BuildingResult or command == CMD.RadiusResult then
        if args then
            _log(string.format("[CL] Result: command=%s action=%s",
                tostring(command), tostring(args.action or "?")))
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)

_log("Client script loaded (v2.0.0)")
