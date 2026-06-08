local uim = require("uimanager")
local cm = require("commandmanager")

-- Open save menu
cm.MANAGER:register(
    "load",
    {
        description = "Open the load game menu (does not pause the game)",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local sgm = FindFirstOf("BP_SaveGameManager_C")
        sgm["Open Save Load Game Menu"](sgm, true)  -- true = loading
        return true
    end
)

-- Open load menu  
cm.MANAGER:register(
    "save",
    {
        description = "Open the save game menu (does not pause the game)",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local sgm = FindFirstOf("BP_SaveGameManager_C")
        sgm["Open Save Load Game Menu"](sgm, false)   -- false = saving
        return true
    end
)   