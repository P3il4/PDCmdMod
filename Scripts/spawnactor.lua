-- ============================================================
-- spawn: Spawn an actor at the player's location.
--
-- Usage:
--   spawn <asset_path>
--     Spawns the actor at the player's location + 200 units forward.
--     e.g. spawn /Game/Gameplay/Hazards/Landmine/BP_Hazard_Landmine
--
-- Notes:
--   - Append _C suffix is handled automatically
--   - Partial paths relative to /Game/ are supported
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local function GetPlayerLocation()
    local player = FindFirstOf("Character")
    if not player then return {X=0, Y=0, Z=0} end
    local ok, loc = pcall(function() return player:K2_GetActorLocation() end)
    if ok and loc then
        return {X=loc.X + 200, Y=loc.Y, Z=loc.Z}
    end
    return {X=0, Y=0, Z=0}
end

local function ResolveSpawnPath(raw)
    -- Add /Game/ prefix if not absolute
    if not raw:match("^/") then
        raw = "/Game/" .. raw
    end
    -- Extract asset name for _C suffix
    local assetName = raw:match("([^/]+)$")
    -- Build full class path if not already has _C
    if not raw:match("_C$") then
        return raw .. "." .. assetName .. "_C"
    end
    return raw
end

-- RegisterConsoleCommandHandler("spawn", function(FullCommand, Parameters)
--     if #Parameters == 0 then
--         uim.sendMessage("Spawn", "Usage: spawn <asset_path>", uim.MessageTypes.ALERT)
--         return true
--     end

--     local raw = Parameters[1]
--     local classPath = ResolveSpawnPath(raw)
--     uim.sendMessage("Spawn", "Resolving: " .. classPath, uim.MessageTypes.LOGS)

--     local class = StaticFindObject(classPath)
--     if not class then
--         uim.sendMessage("Spawn", "Class not found: " .. classPath, uim.MessageTypes.ERR)
--         return true
--     end

--     local world = FindFirstOf("World")
--     if not world then
--         uim.sendMessage("Spawn", "No world found", uim.MessageTypes.ERR)
--         return true
--     end

--     local loc = GetPlayerLocation()
--     local rot = {Pitch=0, Yaw=0, Roll=0}

--     local ok, actor = pcall(function()
--         return world:SpawnActor(class, loc, rot)
--     end)

--     if ok and actor then
--         uim.sendMessage("Spawn", "Spawned '" .. raw .. "'", uim.MessageTypes.CHATLIKE)
--     else
--         uim.sendMessage("Spawn", "Spawn failed: " .. tostring(actor), uim.MessageTypes.LOG)
--         uim.sendMessage("Spawn", "Spawn failed", uim.MessageTypes.ALERT)
--         uim.sendMessage("Spawn", "Failed to spawn '" .. raw .. "'", uim.MessageTypes.CHATLIKE)
--     end

--     return true
-- end)

local cmd = cm.MANAGER:register(
    "spawn",
    {
        description = "Spawn an actor at the player's location.",
        args_syntax = "<asset_path>",
        flags_syntax = nil
    },
    function(args, flags)
        if #args == 0 then
            return false
        end

        local raw = args[1]
        local classPath = ResolveSpawnPath(raw)
        uim.sendMessage("Spawn", "Resolving: " .. classPath, uim.MessageTypes.LOGS)

        local class = StaticFindObject(classPath)
        if not class then
            uim.sendMessage("Spawn", "Class not found: " .. classPath, uim.MessageTypes.ERR)
            return true
        end

        local world = FindFirstOf("World")
        if not world then
            uim.sendMessage("Spawn", "No world found", uim.MessageTypes.ERR)
            return true
        end

        local loc = GetPlayerLocation()
        local rot = {Pitch=0, Yaw=0, Roll=0}

        local ok, actor = pcall(function()
            return world:SpawnActor(class, loc, rot)
        end)

        if ok and actor then
            uim.sendMessage("Spawn", "Spawned '" .. raw .. "'", uim.MessageTypes.CHATLIKE)
        else
            uim.sendMessage("Spawn", "Spawn failed: " .. tostring(actor), uim.MessageTypes.LOGS)
            uim.sendMessage("Spawn", "Spawn failed", uim.MessageTypes.ALERT)
            uim.sendMessage("Spawn", "Failed to spawn '" .. raw .. "'", uim.MessageTypes.CHATLIKE)
        end

        return true
    end
)



RegisterConsoleCommandHandler("spawntest", function(FullCommand, Parameters)
    local pm = FindFirstOf("BP_ProgressionManager_C")
    if not pm then print("[Mod] No PM") return true end

    -- try GetMapWhiteboard
    local world = FindFirstOf("World")
    local ok, wb = pcall(function()
        return pm:GetMapWhiteboard(pm)
    end)
    print("[Mod] wb=" .. tostring(wb))
    print("[Mod] GetMapWhiteboard ok=" .. tostring(ok) .. " wb=" .. tostring(wb))

    if ok and wb then
        local ok2, path = pcall(function() return wb:GetFullName():match("^%S+%s+(.+)$") end)
        if ok2 then
            print("[Mod] Map whiteboard path: " .. path)
            -- Set DryLightning on the MAP whiteboard
            local result = PDSetWhiteboardTag(path, "WB.Modifiers.Anomalies.DryLightning", 1.0)
            print("[Mod] Set tag result: " .. tostring(result))
        end
    end
    return true
end)


RegisterConsoleCommandHandler("spawntest2", function(FullCommand, Parameters)
    local pm = FindFirstOf("BP_ProgressionManager_C")
    if not pm then return true end
    
    local out = {}
    local ok, err = pcall(function()
        pm:GetActiveModifiers(false, out)
    end)
    print("[Mod] ok=" .. tostring(ok))
    print("[Mod] ModifierTags=" .. tostring(out["ModifierTags"]))
    print("[Mod] ModifierAssets=" .. tostring(out["ModifierAssets"]))
    return true
end)



print("[Spawn] Loaded!")
print("[Spawn]   spawn <asset_path>")