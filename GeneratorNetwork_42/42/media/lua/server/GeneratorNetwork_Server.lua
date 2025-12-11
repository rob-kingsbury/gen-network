-- GeneratorNetwork_Server.lua
-- Server-side command handler for Generator Network 0.8.8

require "GeneratorNetwork_Shared"

local GN = GeneratorNetwork

local function _log(msg)
    GN.log("[SV] " .. tostring(msg))
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= GN.ModId then return end

    if not args or not args.x or not args.y or not args.z then
        _log("onClientCommand: missing coordinates")
        return
    end

    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    local action = tostring(command or "none")

    _log(string.format("onClientCommand: %s at %d,%d,%d", action, x, y, z))

    local gens = GN.getGeneratorsAround(x, y, z, GN.ClusterRadius)
    _log(string.format("onClientCommand: found %d generators in cluster", #gens))

    if action == "RefuelCluster" then
        GN.distributeFuelEvenly(gens)
    elseif action == "ClusterOn" then
        GN.setClusterActivated(playerObj, gens, true)
    elseif action == "ClusterOff" then
        GN.setClusterActivated(playerObj, gens, false)
    else
        _log("onClientCommand: unknown action " .. tostring(action))
    end
end

Events.OnClientCommand.Add(onClientCommand)

_log("Server script loaded")
