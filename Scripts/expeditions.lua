local uim = require("uimanager")
local cm = require("commandmanager")


local cmd = cm.MANAGER:register(
    "expedition",
    {
        description = "Expeditions related command(s).",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

local cmd_setlevel = cmd:branch(
    "setlevel",
    {
        description = "[BY SHRUC] Set the current expedition level.",
        detailed_description = "Thanks to Shruc for allowing me to include this script in the PDCmdMod (modified to work with this mod).",
        args_syntax = "<number>",
        flags_syntax = nil
    },
    function(args, flags)
        -- code modified from shruc's expedition mod

        local lvl = tonumber(args[1])
        if lvl == nil then
            uim.sendMessage("Expedition", "Invalid command", uim.MessageTypes.ALERT)
            return false  -- help
        end

        local pm = FindFirstOf("BP_ProgressionManager_C")
        if not pm then
            uim.sendMessage("Expedition", "Save not loaded", uim.MessageTypes.ALERT)
            return true
        end

        local ok, err = pcall(function()
            pm.CurrentExpeditionDifficulty = lvl
            pm.DisplayedExpeditionDifficulty = lvl
            uim.sendMessage("Expedition", "Set expedition level to " .. lvl, uim.MessageTypes.CHATLIKE)
        end)
        if not ok then
            uim.sendMessage("Expedition", "Failed to set expedition level", uim.MessageTypes.ALERT)
            uim.sendMessage("Expedition", "Error: " .. tostring(err), uim.MessageTypes.LOGS)
        end
        return true
    end
)

local cmd_reroll = cmd:branch(
    "reroll_pickphaseonly",
    {
        description = "Reroll expedition offerings. CAN SOFTLOCK YOU, RUN 'pdh expreroll' TO SEE USAGE AND LEARN MORE.",
        detailed_description = "This command will softlock you if the route planner is not currently prompting you to pick one of 3 rewoven hard drives.\n" ..
                               "We recommend you save your game before using this command.\n" ..
                               "Use the flag --iknowwhatimdoing to run this command.\nExit (if not already done) then re-open the route planner to update offers.",
        args_syntax = nil,
        flags_syntax = "Run 'pdh expreroll' and see the full description to learn more",
        aliases = { "expreroll" }
    },
    function(args, flags)

        if not flags or not flags["iknowwhatimdoing"] then
            uim.sendMessage("Expedition", "This command will softlock you if you are not in the menu and must currently pick one of 3 rewoven hard drives.\nSave your game then run with flag --iknowwhatimdoing to reroll.\nExit then re-open the route planner to update offers.", uim.MessageTypes.CHATLIKE, 20.0, true)
            return true
        end

        local pm = FindFirstOf("BP_ProgressionManager_C")
        if not pm then
            uim.sendMessage("Expedition", "Save not loaded", uim.MessageTypes.ALERT)
            return true
        end

        local ok, err = pcall(function()
            pm:ClearAndGenerateNewExpeditions()
        end)
        if ok then
            uim.sendMessage("Expedition", "Expedition offerings rerolled", uim.MessageTypes.CHATLIKE)
        else
            uim.sendMessage("Expedition", "Failed to reroll expeditions", uim.MessageTypes.ALERT)
            uim.sendMessage("Expedition", "Error: " .. tostring(err), uim.MessageTypes.LOGS)
        end
        return true
    end
)
