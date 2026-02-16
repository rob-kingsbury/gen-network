-- GeneratorNetwork_Server.lua
-- Server-side command handler for Generator Network 0.9.0

require "GeneratorNetwork_Shared"

local GN = GeneratorNetwork
local CMD = GN.Commands

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

    if action == CMD.RefuelCluster then
        local count, perFuel = GN.distributeFuelEvenly(gens)
        GN.notifyPlayer(playerObj,
            string.format("Cluster refueled: %d generators at %.1f%% each.", count, perFuel))
        sendServerCommand(playerObj, GN.ModId, CMD.ClusterResult, {
            action = action, count = tostring(count), perFuel = tostring(perFuel)
        })

    elseif action == CMD.ClusterOn then
        local changed, skipped, failed = GN.setClusterActivated(playerObj, gens, true)
        if changed > 0 then
            GN.notifyPlayer(playerObj,
                string.format("Cluster: %d generators activated.", changed))
        end
        sendServerCommand(playerObj, GN.ModId, CMD.ClusterResult, {
            action = action, changed = tostring(changed),
            skipped = tostring(skipped), failed = tostring(failed)
        })

    elseif action == CMD.ClusterOff then
        local changed = GN.setClusterActivated(playerObj, gens, false)
        if changed > 0 then
            GN.notifyPlayer(playerObj,
                string.format("Cluster: %d generators deactivated.", changed))
        end
        sendServerCommand(playerObj, GN.ModId, CMD.ClusterResult, {
            action = action, changed = tostring(changed)
        })

    else
        _log("onClientCommand: unknown action " .. tostring(action))
    end
end

Events.OnClientCommand.Add(onClientCommand)

_log("Server script loaded")
