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
GN.CoverageGridActive = false

--- Draw per-square grid lines over highlighted coverage area (current floor only).
local function _renderCoverageGrid()
    if not GN.HighlightSquares or #GN.HighlightSquares == 0 then
        Events.OnTick.Remove(_renderCoverageGrid)
        GN.CoverageGridActive = false
        return
    end
    local player = getSpecificPlayer(0)
    local pz = player and math.floor(player:getZ()) or 0
    for _, sq in ipairs(GN.HighlightSquares) do
        if sq then
            local x, y, z = sq:getX(), sq:getY(), sq:getZ()
            if z == pz then
                addAreaHighlightForPlayer(0, x, y, x + 1, y + 1, z, 0.2, 0.8, 0.2, 0.15)
            end
        end
    end
end

function GN.clearCoverageHighlights()
    if GN.CoverageGridActive then
        Events.OnTick.Remove(_renderCoverageGrid)
        GN.CoverageGridActive = false
    end
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

--- Highlight all squares belonging to a building (current floor only).
function GN.showBuildingCoverage(building)
    if not building then return end

    GN.clearCoverageHighlights()

    local player = getSpecificPlayer(0)
    local pz = player and math.floor(player:getZ()) or 0

    local squares = GN.getAllBuildingSquares(building)
    if #squares == 0 then
        GN.notifyPlayer(getSpecificPlayer(0), "No building squares found.")
        return
    end

    for _, sq in ipairs(squares) do
        if sq:getZ() == pz then
            local floor = sq:getFloor()
            if floor then
                floor:setHighlighted(true, false)
                floor:setHighlightColor(0.2, 0.8, 0.2, 0.6)
                table.insert(GN.HighlightSquares, sq)
            end
        end
    end

    if not GN.CoverageGridActive then
        Events.OnTick.Add(_renderCoverageGrid)
        GN.CoverageGridActive = true
    end

    _log(string.format("[COVERAGE] highlighted %d building squares", #GN.HighlightSquares))
end

--- Highlight all squares discovered by flood-fill (current floor only).
function GN.showStructureCoverage(squares)
    if not squares or #squares == 0 then
        GN.notifyPlayer(getSpecificPlayer(0), "No structure squares found.")
        return
    end

    GN.clearCoverageHighlights()

    local player = getSpecificPlayer(0)
    local pz = player and math.floor(player:getZ()) or 0

    for _, sq in ipairs(squares) do
        if sq:getZ() == pz then
            local floor = sq:getFloor()
            if floor then
                floor:setHighlighted(true, false)
                floor:setHighlightColor(0.2, 0.8, 0.2, 0.6)
                table.insert(GN.HighlightSquares, sq)
            end
        end
    end

    if not GN.CoverageGridActive then
        Events.OnTick.Add(_renderCoverageGrid)
        GN.CoverageGridActive = true
    end

    _log(string.format("[COVERAGE] highlighted %d structure squares", #GN.HighlightSquares))
end

--- Highlight radius coverage around all generators in a cluster (current floor only).
function GN.showRadiusCoverage(sq)
    if not sq then return end

    local cell = getCell()
    if not cell then
        _log("[COVERAGE] no cell")
        return
    end

    GN.clearCoverageHighlights()

    local player = getSpecificPlayer(0)
    local pz = player and math.floor(player:getZ()) or 0

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
            if gz == pz then
                for wx = gx - radius, gx + radius do
                    for wy = gy - radius, gy + radius do
                        local sq2 = cell:getGridSquare(wx, wy, gz)
                        if sq2 then
                            local floor = sq2:getFloor()
                            if floor then
                                floor:setHighlighted(true, false)
                                floor:setHighlightColor(0.2, 0.8, 0.2, 0.6)
                                table.insert(GN.HighlightSquares, sq2)
                            end
                        end
                    end
                end
            end
        end
    end

    if not GN.CoverageGridActive then
        Events.OnTick.Add(_renderCoverageGrid)
        GN.CoverageGridActive = true
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

    -- Three-way detection: building → structure (flood-fill) → radius fallback.
    local building = GN.getBuildingForGen(gen)
    local structureSquares = nil

    if not building then
        -- Try flood-fill for player-built structures.
        structureSquares = GN.floodFillFrom(sq)
    end

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

    elseif structureSquares then
        -- Structure mode: flood-fill detected enclosed area.
        context:addOption("Turn Structure On", nil, function()
            send(CMD.StructureOn)
        end)

        context:addOption("Turn Structure Off", nil, function()
            send(CMD.StructureOff)
        end)

        context:addOption("Refuel Structure Generators", nil, function()
            send(CMD.RefuelStructure)
        end)

        context:addOption("Show Structure Coverage", nil, function()
            GN.showStructureCoverage(structureSquares)
        end)

    else
        -- Radius fallback: open area, no enclosure detected.
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

    if command == CMD.BuildingResult or command == CMD.StructureResult or command == CMD.RadiusResult then
        if args then
            _log(string.format("[CL] Result: command=%s action=%s",
                tostring(command), tostring(args.action or "?")))
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)

_log("Client script loaded (v2.0.0)")
