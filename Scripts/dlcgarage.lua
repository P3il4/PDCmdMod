-- ============================================================
-- dlcgarage: Permanently enable the DLC garage aesthetic.
--
-- Usage:
--   dlcgarage enable   -- Enable DLC aesthetic, persists on reload
--   dlcgarage disable  -- Disable and stop auto-applying
--   dlcgarage apply    -- Manually apply without saving state
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")
local ds = require("datastorage")

local msg = uim.newMessenger("DLCGarage")

local SAVE_KEY = "dlcgarage_mode"

local function IsInGarage()
    local world = FindFirstOf("World")
    if not world then return false end
    local ok, name = pcall(function() return world:GetFullName() end)
    if not ok or not name then return false end
    return name:lower():find("garage") ~= nil
end

local function GetManager()
    local all = FindAllOf("BP_FIG_GarageMischiefManager_C")
    if not all or #all == 0 then return nil end
    for _, obj in ipairs(all) do
        local ok = pcall(function() return obj:GetClass() end)
        if ok then return obj end
    end
    return nil
end

local function ApplyAesthetic()
    if not IsInGarage() then
        msg:alert("Not in garage", "You must be in the garage to apply the DLC asthetic.")
        return false
    end

    local mgr = GetManager()
    if not mgr then
        msg:alert("Failed", "Failed to find manager. Cannot apply asthetic.")
        msg:logErr("BP_FIG_GarageMischiefManager_C not found")
        return false
    end

    local ok, err = pcall(function() mgr:ApplyIntroAdjustments() end)
    if not ok then
        msg:alert("Failed", "Failed to apply DLC aesthetic")
        msg:logErr("ApplyIntroAdjustments failed: " .. tostring(err))
        return false
    end

    msg:feedback("DLC garage aesthetic applied")
    return true
end

-- Auto-apply on garage load
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    if not ds.get(SAVE_KEY, false) then return end
    ExecuteWithDelay(1000, function()
        if not IsInGarage() then return end
        local mgr = GetManager()
        if not mgr then return end
        pcall(function() mgr:ApplyIntroAdjustments() end)
        msg:logInfo("DLC garage aesthetic auto-applied")
    end)
end)

-- Command registration
local cmd = cm.MANAGER:register(
    "dlcgarage",
    {
        description = "Toggle the DLC garage aesthetic permanently.",
        detailed_description = "Apply the Whispers in the Woods DLC garage asthetic either once or automatically on every garage load if enabled.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

cmd:branch(
    "enable",
    {
        description = "Enable the DLC garage aesthetic and automtically apply on every garage load.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        ds.set(SAVE_KEY, true)
        ApplyAesthetic()
        msg:feedback("DLC garage aesthetic enabled and will persist on reload")
        return true
    end
)

cmd:branch(
    "disable",
    {
        description = "Stop automatically applying the DLC asthetic.",
        detailed_description = "The garage must be reloaded in order to remove WitW asthetic. It will not disable it if the game applies it by itself.\n" ..
                               "If the game applies it by itself, this is because you scanned the mysterious effigy and did not complete the initiation mission yet.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        ds.set(SAVE_KEY, false)
        msg:feedback("DLC garage aesthetic disabled")
        return true
    end
)

cmd:branch(
    "apply",
    {
        description = "Manually apply the DLC garage aesthetic.",
        detailed_description = "Manually apply the DLC garage aesthetic without saving state. This will not persist on reload.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        ApplyAesthetic()
        return true
    end
)

-- Auto-apply on startup if enabled
if ds.get(SAVE_KEY, false) then
    ExecuteWithDelay(2000, function()
        if not IsInGarage() then return end
        local mgr = GetManager()
        if not mgr then return end
        pcall(function() mgr:ApplyIntroAdjustments() end)
        msg:logInfo("DLC garage aesthetic auto-applied on startup")
    end)
end