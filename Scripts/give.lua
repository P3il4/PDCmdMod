local uim = require("uimanager")
local cm = require("commandmanager")


RegisterConsoleCommandHandler("pdtest", function(FullCommand, Parameters)
    local all = FindAllOf("ItemArchetype")
    local ok, fullName = pcall(function() return all[1]:GetFullName() end)
    if not ok then print("[PDTest] GetFullName failed") return true end
    local path = fullName:match("^%S+%s+(.+)$")
    print("[PDTest] Path: " .. tostring(path))
    local title = PDGetFText(path, "Title")
    print("[PDTest] Title: " .. tostring(title))
    return true
end)

-- ============================================================
-- give: Spawn an item into the player's inventory (or drop
--       to world if inventory is full / item is unpickable).
--
-- Usage:
--   give fullpath <full_path> [amount]
--     e.g. give fullpath /Game/Gameplay/Inventory/Items/Resources/Basic/RawLead/IA_Resource_Raw_Lead 5
--     e.g. give fullpath PenDriverPro/Content/Gameplay/Inventory/Items/Resources/Basic/RawLead/IA_Resource_Raw_Lead.uasset 5
--
--   give path <relative_path> [amount]
--     e.g. give path Resources/Basic/RawLead/IA_Resource_Raw_Lead 5
--
--   give id <IA_asset_name> [amount]
--     e.g. give id IA_Resource_Raw_Lead 5
--
--   give name [index] <display_name> [amount]
--     e.g. give name lead platelet 5
--     e.g. give name 2 lead platelet 5   <- index if multiple matches
--
-- Notes:
--   - name mode matches case-insensitively, ignoring spaces/punctuation/dashes
--   - name mode index loops (so index 3 of 2 results = result 1)
--   - If first word after mode is a number, it's treated as an index, not part of name
--   - Amount is always the last parameter if it's a number and comes after the name
--   - Localization: always matches English SourceString, language-independent
-- ============================================================
 
local ITEMS_BASE = "/Game/Gameplay/Inventory/Items/"
 
local function Normalize(s)
    return s:lower():gsub("[%s%p%-]", "")
end
 
local function FindInvManager()
    local im = FindFirstOf("BP_InventoryManager_C")
    if not im or not im:IsValid() then
        uim.sendMessage("Give", "Inventory Manager not found. Is a save loaded?", uim.MessageTypes.ERR)
        -- print("[Give] ERROR: BP_InventoryManager_C not found")
        return nil
    end
    return im
end

local function TryGetDisplayName(itemOrPath)
    local ok, result = pcall(function()

        local path

        if type(itemOrPath) == "string" then
            path = itemOrPath
        else
            if not itemOrPath or not itemOrPath:IsValid() then
                return nil
            end

            local fullName = itemOrPath:GetFullName()

            path = fullName:match("^%S+%s+(.+)$")
        end

        if not path then
            return nil
        end

        local title = PDGetFText(path, "Title")

        if not title or title == "" then
            return nil
        end

        return tostring(title)

    end)

    if ok then
        return result
    end

    return nil
end

local function GiveArchetype(invManager, archetype, count)
    local given = 0
    local problem = false

    for i = 1, count do
        local ok, err = pcall(function()
            invManager:CreateItemInPlayerInventory(archetype, false, false, 3, true)
        end)
        if not ok then
            problem = true
            uim.sendMessage("Give", "Give failed on item " .. i .. ": " .. tostring(err), uim.MessageTypes.LOGS)
            -- (old print identical)
            break
        end
        given = given + 1
    end

    if problem then
        uim.sendMessage("Give", "Failed to give all items", uim.MessageTypes.ALERT)
        uim.sendMessage("Give", "Received " .. given .. "/" .. count .. " item(s)", uim.MessageTypes.CHATLIKE)
    else
        local displayName = TryGetDisplayName(archetype) or "unnamed item"
        uim.sendMessage("Give", "Gave " .. given .. "x " .. displayName, uim.MessageTypes.CHATLIKE)
    end
    --print("[Give] Gave " .. given .. "/" .. count .. " item(s)")
end

local function ResolveArchetype(fullPath)
    local archetype = nil
    pcall(function() archetype = StaticFindObject(fullPath) end)
    if not archetype or not archetype:IsValid() then
        return nil
    end
    return archetype
end
 

-- =====================================================
-- Print prodecures for consistency
-- ======================================================

local function SendMessageBadName(name)
    uim.sendMessage("Give", "Invalid item", uim.MessageTypes.ALERT)
    uim.sendMessage("Give", "Could not find '" .. name .. "'. Use 'give tips' if this is unexpected.", uim.MessageTypes.CHATLIKE)
end


-- ============================================================
-- Mode: fullpath
-- ============================================================
local function HandleFullpath(input, count)
    local fullPath = input:gsub("\\", "/")
    fullPath = fullPath:gsub("^.*Content/", "/Game/")
    fullPath = fullPath:gsub("%.uasset$", "")
    local assetName = fullPath:match("([^/]+)$")
    if not assetName then
        uim.sendMessage("Give", "Failed to parse asset name from path: " .. input, uim.MessageTypes.LOGS)
        SendMessageBadName(input)
        --print("[Give] ERROR: Could not parse asset name from path: " .. input)
        return
    end
    fullPath = fullPath .. "." .. assetName
    
    uim.sendMessage("Give", "Resolving: " .. fullPath, uim.MessageTypes.LOGS)
    --print("[Give] Resolving: " .. fullPath)
    local archetype = ResolveArchetype(fullPath)
    if not archetype then
        uim.sendMessage("Give", "Asset not found: " .. fullPath, uim.MessageTypes.LOGS)
        SendMessageBadName(input)
        --print("[Give] ERROR: Asset not found: " .. fullPath)
        return
    end
    uim.sendMessage("Give", "Found archetype: " .. tostring(archetype), uim.MessageTypes.LOGS)
    -- print("[Give] Found archetype: " .. tostring(archetype))
    local im = FindInvManager()
    if not im then return end
    GiveArchetype(im, archetype, count)
end
 
-- ============================================================
-- Mode: path
-- ============================================================
local ITEMS_BASE = "/Game/Gameplay/Inventory/Items/"
local ITEMS_BASE_DLC_FIG = "/PDFeature_Fig/Gameplay/Inventory/Items/"

local function HandlePath(input, count)
    local assetName = input:match("([^/]+)$")
    if not assetName then
        uim.sendMessage("Give", "Could not parse asset name from path: " .. tostring(input), uim.MessageTypes.LOGS)
        SendMessageBadName(input)
        return
    end

    -- Try base game path first, then DLC
    local fullPath = ITEMS_BASE .. input .. "." .. assetName
    uim.sendMessage("Give", "Resolving: " .. fullPath, uim.MessageTypes.LOGS)
    local archetype = ResolveArchetype(fullPath)

    if not archetype then
        local dlcPath = ITEMS_BASE_DLC_FIG .. input .. "." .. assetName
        uim.sendMessage("Give", "Not found, trying DLC path: " .. dlcPath, uim.MessageTypes.LOGS)
        archetype = ResolveArchetype(dlcPath)
    end

    if not archetype then
        uim.sendMessage("Give", "Asset not found: " .. input, uim.MessageTypes.LOGS)
        SendMessageBadName(input)
        return
    end
    uim.sendMessage("Give", "Found archetype: " .. tostring(archetype), uim.MessageTypes.LOGS)
    local im = FindInvManager()
    if not im then return end
    GiveArchetype(im, archetype, count)
end
 
-- ============================================================
-- Mode: id
-- ============================================================
local function HandleId(input, count)
    local all = FindAllOf("ItemArchetype")
    if not all then
        uim.sendMessage("Give", "FindAllOf(\"ItemArchetype\") returned nil", uim.MessageTypes.ERR)
        --print("[Give] No ItemArchetype objects found in memory")
        return
    end
    uim.sendMessage("Give", "Scanning " .. #all .. " loaded ItemArchetype objects...", uim.MessageTypes.LOGS)
    --print("[Give] Scanning " .. #all .. " loaded ItemArchetype objects...")
 
    -- Step 1: collect paths safely (GetPathName only, no property access)
    local paths = {}
    for i = 1, #all do
        local obj = all[i]
        local ok, fullName = pcall(function() return obj:GetFullName() end)
        if ok and fullName then
            local cleanPath = fullName:match("^%S+%s+(.+)$")
            if cleanPath then
                local assetName = cleanPath:match("([^/.]+)%.[^/]+$")
                if assetName and assetName:lower() == input:lower() then
                    table.insert(paths, cleanPath)
                end
            end
        end
    end

    if #paths == 0 then
        uim.sendMessage("Give", "No loaded archetype matching id: " .. input, uim.MessageTypes.LOGS)
        SendMessageBadName(input)
        --print("[Give] ERROR: No loaded ItemArchetype found with id: " .. input)
        --print("[Give] Tip: use 'give path <relative_path>' if the asset isn't loaded yet")
        return
    end

    local archetype = nil
    for _, cleanPath in ipairs(paths) do
        local fresh = nil
        pcall(function() fresh = StaticFindObject(cleanPath) end)
        if fresh then
            archetype = fresh
            uim.sendMessage("Give", "Matched: " .. cleanPath, uim.MessageTypes.LOGS)
            --print("[Give] Matched: " .. cleanPath)
            break
        end
    end
 
    if not archetype then
        uim.sendMessage("Give", "StaticFindObject failed for all matched paths", uim.MessageTypes.LOGS)
        SendMessageBadName(input)
        --print("[Give] ERROR: Could not load archetype")
        return
    end
 
    local im = FindInvManager()
    if not im then return end
    GiveArchetype(im, archetype, count)
end
 
-- ============================================================
-- Mode: name
-- Uses FindAllOf for paths only, then StaticFindObject for
-- stable pointers before accessing .Title.SourceString
-- ============================================================
local function HandleName(params, flags)
    local function IsInt(s)
        local n = tonumber(s)
        return n ~= nil and math.floor(n) == n
    end

    local index = tonumber(flags.index) or 1
    local count = 1

    local endIdx = #params

    -- Optional trailing amount
    if params[endIdx] and IsInt(params[endIdx]) then
        count = tonumber(params[endIdx])
        endIdx = endIdx - 1
    end

    if endIdx < 1 then
        return false
    end

    local rawName = table.concat(params, " ", 1, endIdx)
    local normalizedInput = Normalize(rawName)

    uim.sendMessage("Give", string.format("Searching for '%s' (index=%d, count=%d)", rawName, index, count), uim.MessageTypes.LOGS)

    local all = FindAllOf("ItemArchetype")
    if not all then
        uim.sendMessage("Give", "FindAllOf(\"ItemArchetype\") returned nil", uim.MessageTypes.ERR)
        --print("[Give] No ItemArchetype objects found in memory")
        return
    end
    uim.sendMessage("Give", "Scanning " .. #all .. " loaded ItemArchetype objects...", uim.MessageTypes.LOGS)
    --print("[Give] Scanning " .. #all .. " loaded ItemArchetype objects...")
 
    -- Step 1: collect all paths safely, no property access
    local paths = {}
    for i = 1, #all do
        local obj = all[i]
        local ok, fullName = pcall(function() return obj:GetFullName() end)
        if ok and fullName then
            local cleanPath = fullName:match("^%S+%s+(.+)$")
            if cleanPath then
                table.insert(paths, cleanPath)
            end
        end
    end
    uim.sendMessage("Give", "Collected " .. #paths .. " valid paths", uim.MessageTypes.LOGS)
    -- print("[Give] Collected " .. #paths .. " valid paths")
 
    -- Step 2: load each fresh via StaticFindObject and access .Title safely
    local matches = {}
    for _, cleanPath in ipairs(paths) do
        local fresh = StaticFindObject(cleanPath)
        if fresh then
            local displayName = PDGetFText(cleanPath, "Title")
            if displayName and Normalize(displayName) == normalizedInput then
                table.insert(matches, { archetype = fresh, displayName = displayName })
            end
        end
    end
 
    if #matches == 0 then
        SendMessageBadName(rawName)
        --print("[Give] ERROR: No item found matching: '" .. rawName .. "'")
        --print("[Give] Tip: try 'give id' or 'give path' if the asset isn't loaded yet")
        return false
    end
 
    local wrapped = ((index - 1) % #matches) + 1
    local chosen = matches[wrapped]
 
    if #matches > 1 then
        uim.sendMessage("Give",
            #matches .. " matches found, using #" .. wrapped,
            uim.MessageTypes.CHATLIKE)

        uim.sendMessage("Give",
            "Chosen: '" .. tostring(chosen.displayName) .. "'",
            uim.MessageTypes.LOGS)
    else
        uim.sendMessage("Give",
            "Matched: '" .. tostring(chosen.displayName) .. "'",
            uim.MessageTypes.LOGS)
    end
 
    local im = FindInvManager()
    if not im then return end
    GiveArchetype(im, chosen.archetype, count)
end



-- ============================================================
-- Modes: tips
-- ============================================================

local function HandleTips()
    uim.sendMessage("Give", "Use 'give help' for usage instructions.\n"
                        ..  "Some modes may encouter issues with DLC items, try different modes if something doesn't work.\n"
                        ..  "The 'give id' mode expects inputs such as IA_Resource_Raw_Lead, not display names like 'Lead Platelet'.\n"
                        ..  "The 'give path' mode's root is 'Game/Gameplay/Inventory/Items/'.\n"
        , uim.MessageTypes.CHATLIKE, 20.0, true
    )
end

-- ============================================================
-- Command handler
-- ============================================================
-- RegisterConsoleCommandHandler("give", function(FullCommand, Parameters)

--     --[[local all = FindAllOf("ItemArchetype")
--     print("[Give] Total: " .. #all)
--     -- try the very first one multiple ways
--     local obj = all[1]
--     print("[Give] obj: " .. tostring(obj))
--     local ok1, r1 = pcall(function() return obj:GetPathName() end)
--     print("[Give] GetPathName: " .. tostring(ok1) .. " / " .. tostring(r1))
--     local ok2, r2 = pcall(function() return obj:GetFullName() end)
--     print("[Give] GetFullName: " .. tostring(ok2) .. " / " .. tostring(r2))
--     local ok3, r3 = pcall(function() return obj:GetName() end)
--     print("[Give] GetName: " .. tostring(ok3) .. " / " .. tostring(r3))]]

--     if #Parameters < 2 and Parameters[1] ~= "help" and Parameters[1] ~= "tips" then
--         HandleHelp(uim.MessageTypes.CHATLIKE)
--         return true
--     end
 
--     local mode = Parameters[1]:lower()
 
--     if mode == "fullpath" then
--         local input = Parameters[2]
--         local count = tonumber(Parameters[3]) or 1
--         if count < 1 then count = 1 end
--         HandleFullpath(input, count)
 
--     elseif mode == "path" then
--         local input = Parameters[2]
--         local count = tonumber(Parameters[3]) or 1
--         if count < 1 then count = 1 end
--         HandlePath(input, count)
 
--     elseif mode == "id" then
--         local input = Parameters[2]
--         local count = tonumber(Parameters[3]) or 1
--         if count < 1 then count = 1 end
--         HandleId(input, count)
 
--     elseif mode == "name" then
--         local nameParams = {}
--         for i = 2, #Parameters do
--             table.insert(nameParams, Parameters[i])
--         end
--         HandleName(nameParams)
 
--     elseif mode == "tips" then
--         HandleTips()

--     elseif mode == "help" then
--         HandleHelp(uim.MessageTypes.CHATLIKE)
--     else
--         uim.sendMessage("Give", "Unknown mode", uim.MessageTypes.ALERT)
--         uim.sendMessage("Give", "Valid modes: fullpath, path, id, name, help, tips", uim.MessageTypes.CHATLIKE)
--     end
 
--     return true
-- end)
 

local cmd = cm.MANAGER:register(
    "give",
    {
        description = "Give items to player. GIVING YOURSELF DLC ITEMS WILL BRICK YOUR SAVE.",
        detailed_description = "Gives item to player depending on display name or ids.\n" ..
                               "Warning: you will not be able to load back into your save if you try to give yourself DLC items.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

local cmd_tips = cmd:branch(
    "tips",
    {
        description = "Tips for using the give command.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        HandleTips()
        return true
    end
)

local cmd_fullpath = cmd:branch(
    "fullpath",
    {
        description = "Give by full asset path, eg. /Game/Gameplay/Inventory/Items/Resources/Basic/RawLead/IA_Resource_Raw_Lead",
        args_syntax = "<full_path> [amount]",
        flags_syntax = nil
    },
    function(args, flags)
        local input = args[1]
        local count = tonumber(args[2]) or 1
        if count < 1 then count = 1 end
        HandleFullpath(input, count)
        return true
    end
)

local cmd_path = cmd:branch(
    "path",
    {
        description = "Give by asset path, eg. Resources/Basic/RawLead/IA_Resource_Raw_Lead",
        args_syntax = "<path> [amount]",
        flags_syntax = nil
    },
    function(args, flags)
        local input = args[1]
        local count = tonumber(args[2]) or 1
        if count < 1 then count = 1 end
        HandlePath(input, count)
        return true
    end
)

local cmd_id = cmd:branch(
    "id",
    {
        description = "Give by id, eg. IA_Resource_Raw_Lead 3",
        args_syntax = "<id> [amount]",
        flags_syntax = nil
    },
    function(args, flags)
        local input = args[1]
        local count = tonumber(args[2]) or 1
        if count < 1 then count = 1 end
        HandleId(input, count)
        return true
    end
)

local cmd_name = cmd:branch(
    "name",
    {
        description = "Give by display name. You may use the index flag to specify which item to give if there are multiple matches.",
        args_syntax = "<display_name> [amount]",
        flags_syntax = "--index=<index>"
    },
    function(args, flags)
        return HandleName(args, flags)
    end
)



-- SHARE STUFF

local give_module = {}

give_module.GiveArchetype = GiveArchetype

return give_module
