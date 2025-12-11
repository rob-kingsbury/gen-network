-- GeneratorNetwork_Client.lua
-- Client-side context menu + command sender for Generator Network 0.8.8
-- Adds "Show Cluster Coverage" that persists until the next context menu is opened.

require "GeneratorNetwork_Shared"

local GN = GeneratorNetwork

local function _log(msg)
    GN.log("[CL] " .. tostring(msg))
end

-- ------------------------------------------------------------------------
-- Cluster coverage highlighting (visual only, client-side)
-- ------------------------------------------------------------------------

GN.HighlightSquares = GN.HighlightSquares or {}

function GN.clearCoverageHighlights()
    if not GN.HighlightSquares then return end
    for _, sq in ipairs(GN.HighlightSquares) do
        if sq and not sq:isNull() then
            local floor = sq:getFloor()
            if floor then
                floor:setHighlighted(false)
            end
        end
    end
    GN.HighlightSquares = {}
    _log("[COVERAGE] cleared highlights")
end

function GN.showClusterCoverageFromSquare(sq)
    if not sq then return end

    local cell = getCell()
    if not cell then
        _log("[COVERAGE] no cell")
        return
    end

    -- Clear any previous coverage before drawing a new one.
    GN.clearCoverageHighlights()

    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local radius = GN.ClusterRadius or 20

    _log(string.format("[COVERAGE] starting coverage from %d,%d,%d radius=%d", x, y, z, radius))

    local gens = GN.getGeneratorsAround(x, y, z, radius)
    _log(string.format("[COVERAGE] coverage cluster has %d generators", #gens))

    if #gens == 0 then
        GN.notifyPlayer(getSpecificPlayer(0), "No generators found in this cluster.")
        return
    end

    for _, gen in ipairs(gens) do
        if GN.isValidGen and GN.isValidGen(gen) then
            local gx, gy, gz = gen:getX(), gen:getY(), gen:getZ()
            _log(string.format("[COVERAGE] processing gen at %d,%d,%d", gx, gy, gz))
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
        else
            _log("[COVERAGE] skipping invalid generator in coverage cluster")
        end
    end

    _log(string.format("[COVERAGE] highlighted %d squares", #GN.HighlightSquares))
end

-- ------------------------------------------------------------------------
-- Context menu + cluster commands
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

    -- Opening any new context menu clears previous coverage.
    GN.clearCoverageHighlights()

    local gen, sq = getGeneratorFromWorldObjects(worldobjects)
    if not gen or not sq then return end

    local x, y, z = sq:getX(), sq:getY(), sq:getZ()

    local function send(action)
        _log(string.format("send %s at %d,%d,%d", tostring(action), x, y, z))
        sendClientCommand(GN.ModId, action, { x = x, y = y, z = z })
    end

    context:addOption("Refuel Cluster", nil, function()
        send("RefuelCluster")
    end)

    context:addOption("Turn Cluster On", nil, function()
        send("ClusterOn")
    end)

    context:addOption("Turn Cluster Off", nil, function()
        send("ClusterOff")
    end)

    context:addOption("Show Cluster Coverage", nil, function()
        GN.showClusterCoverageFromSquare(sq)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

_log("Client script loaded")
