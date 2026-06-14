local uim = require("uimanager")
local cm = require("commandmanager")

local invisibleEnabled = true
local instabilityEnabled = true


local function SetInvisibleBlockersCollision(enabled)
    local blockers = FindAllOf("BP_InvisibleBlocker_C")
    if blockers then
        for _, b in ipairs(blockers) do
            pcall(function() b:SetActorEnableCollision(enabled) end)
        end
    end
end

local function SetInstabilityWallsEnabled(enabled)
    local oobs = FindAllOf("BP_OutOfBounds_Base_C")

    if oobs then
        for _, oob in ipairs(oobs) do
            if oob then
                print((enabled and "Enabling" or "Disabling") .. ": " .. oob:GetFullName())
                oob:SetActorTickEnabled(enabled)
            end
        end
    end
end

local function ChangeState(invisible, instability) -- true / false to change, nil to ignore.
    if invisible ~= nil then
        SetInvisibleBlockersCollision(invisible)
    end
    if instability ~= nil then
        SetInstabilityWallsEnabled(instability)
    end

    if invisible == instability then
        uim.sendMessage("NoBorders", "Invisible and instability walls are now " .. (invisible and "enabled" or "disabled") .. ".", uim.MessageTypes.CHATLIKE)
    else
        if invisible ~= nil then
            uim.sendMessage("NoBorders", "Invisible walls are now " .. (invisible and "enabled" or "disabled") .. ".", uim.MessageTypes.CHATLIKE)
        end
        if instability ~= nil then
            uim.sendMessage("NoBorders", "Instability walls are now " .. (instability and "enabled" or "disabled") .. ".", uim.MessageTypes.CHATLIKE)
        end
    end
end


local cmd_borders = cm.MANAGER:register(
    "borders",
    {
        description = "Command to toggle invisible and instability walls.",
        detailed_description = "This command allows you to toggle invisible walls and instability walls on or off.\n" ..
                               "You will still be teleported back if you fall off the map.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil  -- nil → shows help for this command. note the previous argument is only a description.
)

local cmd_borders_toggle = cmd_borders:branch(
    "toggle",
    {
        description = "Toggles both invisible and instability walls on or off.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        if invisibleEnabled == instabilityEnabled then
            invisibleEnabled = not invisibleEnabled
            instabilityEnabled = not instabilityEnabled
            ChangeState(invisibleEnabled, instabilityEnabled)  -- takes care of message
        else
            uim.sendMessage("NoBorders", "Cannot toggle borders", uim.MessageTypes.CHATLIKE)
            uim.sendMessage("NoBorders", "Cannot toggle border states because they are not equal. Use 'borders enable' or 'borders disable'.", uim.MessageTypes.CHATLIKE)
        end
        return true
    end
)

local cmd_borders_enable = cmd_borders:branch(
    "enable",
    {
        description = "Enables invisible and instability walls.",
        args_syntax = "[target: 'invisible'/'instability']",
        flags_syntax = nil
    },
    function(args, flags)

        local target = args[1] and args[1]:lower()
        if target == nil then
            invisibleEnabled = true
            instabilityEnabled = true
            ChangeState(true, true)
        elseif target == "invisible" then
            invisibleEnabled = true
            ChangeState(true, nil)
        elseif target == "instability" then
            instabilityEnabled = true
            ChangeState(nil, true)
        else
            uim.sendMessage("NoBorders", "Unknown target", uim.MessageTypes.ALERT)
            uim.sendMessage("NoBorders", "Valid targets: invisible, instability. Leave empty to edit both.", uim.MessageTypes.CHATLIKE)
        end
        return true
    end
)

local cmd_borders_disable = cmd_borders:branch(
    "disable",
    {
        description = "Disables invisible and instability walls.",
        args_syntax = "[target: 'invisible'/'instability']",
        flags_syntax = nil
    },
    function(args, flags)
        local target = args[1] and args[1]:lower()
        if target == nil then
            invisibleEnabled = false
            instabilityEnabled = false
            ChangeState(false, false)
        elseif target == "invisible" then
            invisibleEnabled = false
            ChangeState(false, nil)
        elseif target == "instability" then
            instabilityEnabled = false
            ChangeState(nil, false)
        else
            uim.sendMessage("NoBorders", "Unknown target", uim.MessageTypes.ALERT)
            uim.sendMessage("NoBorders", "Valid targets: invisible, instability. Leave empty to edit both.", uim.MessageTypes.CHATLIKE)
        end
        return true
     end
)
