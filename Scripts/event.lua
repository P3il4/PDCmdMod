-- ============================================================
-- event: Trigger gameplay events in the current junction.
--
-- Usage:
--   event force
--     Triggers a random event (typically wind squall).
--
--   event positive
--     Triggers a positive loot event.
--
--   event debug <partial name>
--     Calls any function on the GameplayEventDirector by partial
--     name match. Case insensitive.
--     e.g. event debug fog
--          event debug seismic
--          event debug swarmer electric
--
-- Notes:
--   - Must be in a junction (not garage) for director to exist.
--   - Some events may crash the game (known game bugs).
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("Event")

local function GetDirector()
    local all = FindAllOf("BP_GameplayEventDirector_C")
    if not all or #all == 0 then return nil end
    for _, obj in ipairs(all) do
        local classOk = pcall(function() return obj:GetClass() end)
        if classOk then return obj end
    end
    return nil
end


-- RegisterConsoleCommandHandler("event", function(FullCommand, Parameters)
--     if #Parameters == 0 then
--         HandleHelp(uim.MessageTypes.CHATLIKE)
--         return true
--     end

--     local mode = Parameters[1]:lower()

--     if mode == "force" then
--         local ged = GetDirector()
--         if not ged then
--             uim.sendMessage("Event", "No director. Must be in a junction", uim.MessageTypes.ERR)
--             return true
--         end
--         local ok, err = pcall(function() ged:ForceStartEvent() end)
--         if ok then
--             uim.sendMessage("Event", "Forced random event", uim.MessageTypes.CHATLIKE)
--         else
--             uim.sendMessage("Event", "Force event failed", uim.MessageTypes.ALERT)
--             uim.sendMessage("Event", "Failed: " .. tostring(err), uim.MessageTypes.LOGS)
--         end

--     elseif mode == "positive" then
--         local ged = GetDirector()
--         if not ged then
--             uim.sendMessage("Event", "No director. Must be in a junction", uim.MessageTypes.ERR)
--             return true
--         end
--         local ok, err = pcall(function() ged:ForcedPositiveEvent() end)
--         if ok then
--             uim.sendMessage("Event", "Forced positive event", uim.MessageTypes.CHATLIKE)
--         else
--             uim.sendMessage("Event", "Force positive event failed", uim.MessageTypes.ALERT)
--             uim.sendMessage("Event", "Failed: " .. tostring(err), uim.MessageTypes.LOGS)
--         end

--     elseif mode == "debug" then
--         if #Parameters < 2 then
--             HandleHelp()
--             return true
--         end

--         local ged = GetDirector()
--         if not ged then
--             uim.sendMessage("Event", "No director. Must be in a junction", uim.MessageTypes.ERR)
--             return true
--         end

--         local search = table.concat(Parameters, " ", 2):lower()
--         local gedPath = ged:GetFullName():match("^%S+%s+(.+)$")
--         local funcs = PDEnumerateFunctions(gedPath)
--         local matches = {}
--         if funcs then
--             for _, f in ipairs(funcs) do
--                 if f:lower():find(search, 1, true) then
--                     table.insert(matches, f)
--                 end
--             end
--         end

--         if #matches == 0 then
--             uim.sendMessage("Event", "No function matching: " .. search, uim.MessageTypes.ERR)
--         elseif #matches == 1 then
--             local ok, err = pcall(function() ged[matches[1]](ged) end)
--             if ok then
--                 uim.sendMessage("Event", "Called: " .. matches[1], uim.MessageTypes.CHATLIKE)
--             else
--                 uim.sendMessage("Event", "Failed: " .. tostring(err), uim.MessageTypes.ERR)
--             end
--         else
--             uim.sendMessage("Event", #matches .. " matches for '" .. search .. "':", uim.MessageTypes.ALERT)
--             for _, f in ipairs(matches) do
--                 uim.sendMessage("Event", f, uim.MessageTypes.CHATLIKE)
--             end
--             uim.sendMessage("Event", "Be more specific", uim.MessageTypes.CHATLIKE)
--         end

--     else
--         HandleHelp(uim.MessageTypes.CHATLIKE)  -- also do event help lmao
--     end

--     return true
-- end)

local cmd = cm.MANAGER:register(
    "event",
    {
        description = "DEPRECATED. Manually trigger events. This command is unstable and can cause issues",
        detailed_description = "We recommend you use 'widget open UMG_StatusEffectTools' (misleading name) instead.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)


local cmd_force = cmd:branch(
    "force",
    {
        description = "Triggers a random event.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local ged = GetDirector()
        if not ged then
            msg:logErr("No director. Must be in a junction")
            return true
        end
        local ok, err = pcall(function() ged:ForceStartEvent() end)
        if ok then
            msg:feedback("Forced random event")
        else
            msg:alert("Force event failed")
            msg:logInfo("Failed: " .. tostring(err))
        end
        return true
    end
)


local cmd_positive = cmd:branch(
    "positive",
    {
        description = "Triggers a positive loot event.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local ged = GetDirector()
        if not ged then
            msg:logErr("No director. Must be in a junction")
            return true
        end
        local ok, err = pcall(function() ged:ForcedPositiveEvent() end)
        if ok then
            msg:feedback("Forced positive event")
        else
            msg:alert("Force positive event failed")
            msg:logInfo("Failed: " .. tostring(err))
        end
        return true
    end
)


local cmd_debug = cmd:branch(
    "debug",
    {
        description = "Calls any function on the GameplayEventDirector by partial name match. Case insensitive.",
        args_syntax = "<partial name>",
        flags_syntax = nil
    },
    function(args, flags)
        local ged = GetDirector()
        if not ged then
            msg:logErr("No director. Must be in a junction")
            return true
        end

        local search = table.concat(args, " "):lower()
        local gedPath = ged:GetFullName():match("^%S+%s+(.+)$")
        local funcs = PDEnumerateFunctions(gedPath)
        local matches = {}
        if funcs then
            for _, f in ipairs(funcs) do
                if f:lower():find(search, 1, true) then
                    table.insert(matches, f)
                end
            end
        end

        if #matches == 0 then
            msg:logErr("No function matching: " .. search)
        elseif #matches == 1 then
            local ok, err = pcall(function() ged[matches[1]](ged) end)
            if ok then
                msg:feedback("Called: " .. matches[1])
            else
                msg:logErr("Failed: " .. tostring(err))
            end
        else
            msg:alert(#matches .. " matches for '" .. search .. "':")
            for _, f in ipairs(matches) do
                msg:feedback(f)
            end
            msg:feedback("Be more specific")
        end

        return true
    end
)
