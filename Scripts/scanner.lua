
-- ============================================================
-- scanner: Read and modify the Zone Scanner's reveal charges.
--
-- Usage:
--   scanner get              -- read current / total charges (alias: scannercharges)
--   scanner set <n>          -- set how many charges are currently available
--   scanner add <n>          -- add to available charges (negative to subtract)
--   scanner setmax <n>       -- set the maximum charge capacity
--   scanner recharge         -- refill charges to full (alias: refill)
--
-- "N SCANNER CHARGES" in the route planner UI is the reveal-charge system on
-- BP_ProgressionManager_C. Charges Left = MaxRevealCharges - RevealsConsumed.
-- Total/Max is a manager property; RevealsConsumed is stored per active chart
-- (via BP_ChartManager), so `set`/`add` can no-op when no chart is active
-- (e.g. in the garage). `setmax` + `recharge` always work.
--
-- All operations call the game's own BlueprintCallable UFUNCTIONs:
--   GetRevealCharges / RechargeReveals / SetMaxRevealCharges / SetRevealsConsumed
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local SRC = "Scanner"

local function GetProgressionManager()
    local pm = FindFirstOf("BP_ProgressionManager_C")
    if not pm or not pm:IsValid() then
        uim.sendMessage(SRC, "Progression Manager not found. Is a save loaded?", uim.MessageTypes.ERR)
        return nil
    end
    return pm
end

-- Read the current charge state. GetRevealCharges has three out-params; UE4SS
-- requires all arg slots be passed but writes every out-param into the FIRST
-- table (by name), same convention as fatigue's GetFatigue.
local function ReadChargesQuiet(pm)
    local out = {}
    local ok = pcall(function() pm:GetRevealCharges(out, {}, {}) end)
    if not ok then return nil end
    return {
        canReveal = out["Can Reveal"],
        left      = out["Reveals Left"],
        total     = out["Total Charges"],
    }
end

local function ShowReadout(v)
    local leftText  = (type(v.left) == "number")  and tostring(v.left)  or "?"
    local totalText = (type(v.total) == "number") and tostring(v.total) or "?"
    uim.sendMessage(SRC, string.format(
        "Scanner charges: %s / %s%s",
        leftText, totalText,
        (v.canReveal == false) and " (cannot reveal right now)" or ""),
        uim.MessageTypes.CHATLIKE, 10.0, true)
end

-- ============================================================
-- Handlers
-- ============================================================

local function HandleGet()
    local pm = GetProgressionManager()
    if not pm then return true end
    local v = ReadChargesQuiet(pm)
    if not v then
        uim.sendMessage(SRC, "GetRevealCharges failed.", uim.MessageTypes.ERR)
        return true
    end
    ShowReadout(v)
    return true
end

local function HandleRecharge()
    local pm = GetProgressionManager()
    if not pm then return true end
    local ok, err = pcall(function() pm:RechargeReveals() end)
    if not ok then
        uim.sendMessage(SRC, "RechargeReveals failed: " .. tostring(err), uim.MessageTypes.ERR)
        return true
    end
    local v = ReadChargesQuiet(pm)
    if v then ShowReadout(v) end
    return true
end

local function HandleSetMax(args)
    local n = tonumber(args[1])
    if not n or n < 0 then
        uim.sendMessage(SRC, "Usage: scanner setmax <n> (n >= 0)", uim.MessageTypes.ALERT)
        return true
    end
    local pm = GetProgressionManager()
    if not pm then return true end
    local ok, err = pcall(function() pm:SetMaxRevealCharges(math.floor(n)) end)
    if not ok then
        uim.sendMessage(SRC, "SetMaxRevealCharges failed: " .. tostring(err), uim.MessageTypes.ERR)
        return true
    end
    local v = ReadChargesQuiet(pm)
    if v then ShowReadout(v) end
    return true
end

-- Drive "Reveals Left" to `target` by writing RevealsConsumed = max - target,
-- raising the cap first when target exceeds it. Consumed lives on the active
-- chart, so this can silently no-op without a chart loaded.
local function SetChargesLeft(pm, target)
    if target < 0 then target = 0 end
    local max = pm.MaxRevealCharges or 0
    if target > max then
        pcall(function() pm:SetMaxRevealCharges(target) end)
        max = target
    end
    return pcall(function() pm:SetRevealsConsumed(max - target) end)
end

local function HandleSet(args)
    local n = tonumber(args[1])
    if not n then
        uim.sendMessage(SRC, "Usage: scanner set <n>", uim.MessageTypes.ALERT)
        return true
    end
    local pm = GetProgressionManager()
    if not pm then return true end

    local ok, err = SetChargesLeft(pm, math.floor(n))
    if not ok then
        uim.sendMessage(SRC, "Failed to set charges: " .. tostring(err) ..
            "\n(Is a region chart active? Charges are stored per chart.)", uim.MessageTypes.ERR)
        return true
    end
    local v = ReadChargesQuiet(pm)
    if v then ShowReadout(v) end
    return true
end

local function HandleAdd(args)
    local delta = tonumber(args[1])
    if not delta then
        uim.sendMessage(SRC, "Usage: scanner add <n> (negative to subtract)", uim.MessageTypes.ALERT)
        return true
    end
    local pm = GetProgressionManager()
    if not pm then return true end

    local cur = ReadChargesQuiet(pm)
    if not cur or type(cur.left) ~= "number" then
        uim.sendMessage(SRC, "Could not read current charges.", uim.MessageTypes.ERR)
        return true
    end

    local ok, err = SetChargesLeft(pm, math.floor(cur.left + delta))
    if not ok then
        uim.sendMessage(SRC, "Failed to add charges: " .. tostring(err) ..
            "\n(Is a region chart active? Charges are stored per chart.)", uim.MessageTypes.ERR)
        return true
    end
    local v = ReadChargesQuiet(pm)
    if v then ShowReadout(v) end
    return true
end

-- ============================================================
-- Command registration
-- ============================================================

local cmd = cm.MANAGER:register(
    "scanner",
    {
        description = "Read and modify the Zone Scanner's reveal charges.",
        detailed_description = "Charges Left = Max capacity - charges consumed on the active region chart.\n" ..
                               "'setmax' and 'recharge' always work; 'set'/'add' change the per-chart consumed\n" ..
                               "count and may no-op when no region chart is active (e.g. in the garage).",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

cmd:branch(
    "get",
    {
        description = "Read the current and total scanner charges.",
        args_syntax = nil,
        flags_syntax = nil,
        aliases = "scannercharges"
    },
    function(args, flags) return HandleGet() end
)

cmd:branch(
    "set",
    {
        description = "Set how many scanner charges are currently available, eg. 'scanner set 5'.",
        args_syntax = "<n>",
        flags_syntax = nil
    },
    function(args, flags) return HandleSet(args) end
)

cmd:branch(
    "add",
    {
        description = "Add to the available scanner charges (negative to subtract), eg. 'scanner add 3'.",
        args_syntax = "<n>",
        flags_syntax = nil
    },
    function(args, flags) return HandleAdd(args) end
)

cmd:branch(
    "setmax",
    {
        description = "Set the maximum scanner charge capacity, eg. 'scanner setmax 8'.",
        args_syntax = "<n>",
        flags_syntax = nil
    },
    function(args, flags) return HandleSetMax(args) end
)

cmd:branch(
    "recharge",
    {
        description = "Refill scanner charges to full.",
        args_syntax = nil,
        flags_syntax = nil,
        aliases = "refill"
    },
    function(args, flags) return HandleRecharge() end
)
