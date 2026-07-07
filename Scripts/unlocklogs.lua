-- ============================================================
-- unlocklogs: Unlock logbook entries.
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("UnlockLogs")

local function Normalize(s)
    return s:lower():gsub("[%s%p%-]", "")
end

local function GetLogBook()
    local lb = FindFirstOf("LogBook")
    if not lb or not lb:IsValid() then
        msg:logErr("LogBook not found")
        return nil
    end
    return lb
end

-- Collect all LogBookDataGeneric objects with metadata
local function CollectEntries()
    local all = FindAllOf("LogBookDataGeneric")
    if not all then
        msg:logErr("No LogBookDataGeneric objects found in memory")
        return nil
    end

    local entries = {}
    for i = 1, #all do
        local obj = all[i]
        local classOk = pcall(function() return obj:GetClass() end)
        if classOk then
            local ok, fullName = pcall(function() return obj:GetFullName() end)
            if ok and fullName then
                local path = fullName:match("^%S+%s+(.+)$")
                local assetName = path and path:match("([^/.]+)%.[^/]+$") or "?"
                local displayName = nil
                if path then
                    pcall(function()
                        displayName = PDGetFText(path, "Title")
                    end)
                end
                table.insert(entries, {
                    obj = obj,
                    path = path,
                    assetName = assetName,
                    displayName = displayName or assetName,
                })
            end
        end
    end
    return entries
end

local function UnlockEntry(lb, entry)
    local ok = pcall(function()
        entry.obj.bCanAddToLogBook = true
        lb:AddEntry(entry.obj)
    end)
    return ok
end

-- ============================================================
-- Mode: all
-- ============================================================
local function HandleAll(includeHidden)
    local lb = GetLogBook()
    if not lb then return end

    -- Pass 1: flip bCanAddToLogBook on all LogBookDataGeneric including hidden
    local all = FindAllOf("LogBookDataGeneric") or {}
    if includeHidden then
        for _, obj in ipairs(all) do
            pcall(function() obj.bCanAddToLogBook = true end)
        end
        msg:logInfo("Flipped bCanAddToLogBook on " .. #all .. " entries")
    end

    -- Pass 2: AddEntry on all LogBookDataGeneric
    local count1 = 0
    for _, obj in ipairs(all) do
        local ok = pcall(function() lb:AddEntry(obj) end)
        if ok then count1 = count1 + 1 end
    end
    msg:logInfo("AddEntry pass 1: " .. count1 .. "/" .. #all)

    -- Pass 3: GetAllLoggableObjects + AddEntry for embedded entries
    local count2 = 0
    local ok, result = pcall(function() return lb:GetAllLoggableObjects() end)
    if ok and result then
        for k, v in pairs(result) do
            pcall(function()
                local obj = v:get()
                if obj then
                    lb:AddEntry(obj)
                    count2 = count2 + 1
                end
            end)
        end
    end
    msg:logInfo("AddEntry pass 2: " .. count2 .. " loggable objects")

    if includeHidden then
        msg:feedback("You must save then load your save to see hidden entries. Closing the game will make hidden entries hidden again.", 15.0)
    end
    msg:feedback("Unlocked all logbook entries.")
end

-- ============================================================
-- Mode: name
-- ============================================================
local function HandleName(args)
    if not args[1] then
        msg:alert("Usage: unlocklogs name <display_name>")
        return
    end

    local rawName = args[1]  -- already space-handled by command manager
    local normalizedInput = Normalize(rawName)

    local lb = GetLogBook()
    if not lb then return end

    local entries = CollectEntries()
    if not entries then return end

    local matches = {}
    for _, entry in ipairs(entries) do
        if Normalize(entry.displayName) == normalizedInput then
            table.insert(matches, entry)
        end
    end

    if #matches == 0 then
        msg:alert("No matching logbook entry found.")
        msg:feedback("No matches for '" .. rawName .. "'. Try 'unlocklogs id' with an asset path.")
        return
    end

    if #matches == 1 then
        if UnlockEntry(lb, matches[1]) then
            msg:feedback("Unlocked: " .. matches[1].displayName)
        else
            msg:logErr("Unlock failed for: " .. matches[1].displayName)
        end
    else
        local outputString = #matches .. " entries match '" .. rawName .. "':\n"
        for i, entry in ipairs(matches) do
            outputString = outputString .. "  [" .. i .. "] " .. entry.displayName .. " → " .. tostring(entry.path) .. "\n"
        end
        msg:feedback(outputString .. "Use 'unlocklogs id <path>' to unlock a specific one.", 30.0, "\n")
    end
end

-- ============================================================
-- Mode: id
-- ============================================================
local function HandleId(args)
    if not args[1] then
        msg:alert("Usage: unlocklogs id <asset_path>")
        return
    end

    local path = args[1]

    local lb = GetLogBook()
    if not lb then return end

    local entries = CollectEntries()
    if not entries then return end

    local match = nil
    for _, entry in ipairs(entries) do
        if entry.path == path or entry.assetName == path then
            match = entry
            break
        end
    end

    if not match then
        msg:alert("Entry not found")
        msg:feedback("No loaded entry found with path: " .. path)
        return
    end

    if UnlockEntry(lb, match) then
        msg:feedback("Unlocked: " .. match.displayName .. " (" .. match.assetName .. ")")
    else
        msg:logErr("Unlock failed for: " .. match.displayName)
    end
end

-- ============================================================
-- Command registration
-- ============================================================

local cmd = cm.MANAGER:register(
    "unlocklogs",
    {
        description = "Unlock logbook entries.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

cmd:branch(
    "all",
    {
        description = "Unlocks all logbook entries. Has --hidden flag to include hidden entries. Reload save to show hidden entries, restart game to hide.",
        args_syntax = nil,
        flags_syntax = "--hidden"
    },
    function(args, flags)
        local includeHidden = flags and flags["hidden"] or false
        HandleAll(includeHidden)
        return true
    end
)

cmd:branch(
    "name",
    {
        description = "Unlock a logbook entry by display name. Supports quoted names with spaces.",
        args_syntax = "<display_name>",
        flags_syntax = nil
    },
    function(args, flags)
        HandleName(args)
        return true
    end
)

cmd:branch(
    "id",
    {
        description = "Unlock a logbook entry by exact asset path or asset name.",
        args_syntax = "<asset_path>",
        flags_syntax = nil
    },
    function(args, flags)
        HandleId(args)
        return true
    end
)
