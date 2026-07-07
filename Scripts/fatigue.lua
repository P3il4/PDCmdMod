-- ============================================================
-- fatigue: Read and drive the (hidden) Fatigue bar of the item in hand.
--
-- Usage:
--   fatigue get            -- read the held part's fatigue (alias: getfatigue)
--   fatigue set <value>    -- set current fatigue directly
--   fatigue add <value>    -- add to current fatigue (negative to subtract)
--   fatigue age            -- push fatigue to its threshold to age the part
--                             the game-native way (fires MSG_MaxFatigue)
--   fatigue rate get|set   -- read/set the GLOBAL fatigue rate multiplier
--
-- Fatigue is a hidden per-part bar (UI flag HideDescriptor) separate from
-- Durability. When it reaches its max threshold the game fires MSG_MaxFatigue
-- and the part's age status effect (worn/fragile/rusty/etc.) applies. Only car
-- parts carry a BP_FatigueComponent — other items report "no fatigue".
--
-- See the Fatigue section of KNOWLEDGEBASE.md for the full research writeup.
--
-- Implementation: the item in hand gives us a UItemInstance (handSlot:GetItem(0)
-- — note handSlot.ItemInstance is a FAKE property that returns garbage). Each
-- live BP_FatigueComponent_C (a UItemPropertyComponent) has an .Instance
-- back-reference, so we scan for the component whose .Instance matches the hand
-- item. Its GetFatigue/SetFatigue/AddFatigue are Blueprint UFUNCTIONs.
--
-- UE4SS note: GetFatigue has five out-params; UE4SS requires all five argument
-- slots be passed but writes EVERY out-param into the FIRST table (by name).
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("Fatigue")

-- "ClassName /Full/Path.Obj" -> "/Full/Path.Obj" (nil on failure)
local function PathOf(obj)
    if not obj then return nil end
    local ok, full = pcall(function() return obj:GetFullName() end)
    if not ok or not full then return nil end
    return full:match("^%S+%s+(.+)$")
end

-- Returns the UItemInstance currently held in hand, or nil (after messaging).
local function GetHandInstance()
    local im = FindFirstOf("BP_InventoryManager_C")
    if not im or not im:IsValid() then
        msg:logErr("Inventory Manager not found. Is a save loaded?")
        return nil
    end

    local handSlotOut = {}
    pcall(function() im:GetHandSlot(handSlotOut, {}) end)

    local handSlot = handSlotOut["Hand Slot"]
    if not handSlot or not handSlot:IsValid() then
        msg:feedback("Nothing in hand. Hold an item first.")
        return nil
    end

    -- The slot's real item list is the `Items` TArray<UItemInstance*>
    -- (UItemSlot). handSlot.ItemInstance is NOT a real property and returns a
    -- bogus wrapper, so use GetItem(0) with the Items array as a fallback.
    -- (Read-only access ONLY — do not call mutating slot fns here.)
    local instance = nil
    pcall(function() instance = handSlot:GetItem(0) end)
    if not instance then
        pcall(function()
            local items = handSlot.Items
            if items and #items > 0 then instance = items[1] end
        end)
    end

    if not instance or not instance:IsValid() then
        msg:logErr("Hand item has no item instance.")
        return nil
    end
    return instance
end

-- All live BP_FatigueComponent_C belonging to `instance` (often there's just
-- one, but a part can briefly have a manifestation copy alongside another).
local function FindFatigueComponents(instance)
    local instPath = PathOf(instance)
    if not instPath then return {} end

    local matches = {}
    for _, comp in ipairs(FindAllOf("BP_FatigueComponent_C") or {}) do
        local owner = nil
        pcall(function() owner = comp.Instance end)
        if PathOf(owner) == instPath then
            table.insert(matches, comp)
        end
    end
    return matches
end

-- Best-effort display name of the hand item.
local function ItemDisplayName(instance)
    local name = nil
    pcall(function()
        local path = PathOf(instance.Archetype)
        if path then
            local title = PDGetFText(path, "Title")
            if title and title ~= "" then name = tostring(title) end
        end
    end)
    return name or "item in hand"
end

-- Read all five fatigue out-params off a component. No messaging; returns a
-- table or nil. (UE4SS requires all five arg slots but writes every out-param
-- into the FIRST table, keyed by param name.)
local function ReadFatigueQuiet(comp)
    local out = {}
    local ok = pcall(function() comp:GetFatigue(out, {}, {}, {}, {}) end)
    if not ok then return nil end
    return {
        fatigue  = out["Fatigue"],
        max      = out["MaxFatigue"],
        interval = out["FatigueIntervalSize"],
        accrued  = out["FatigueIntervalsAccrued"],
        percent  = out["PercentFatigued"],
    }
end

-- Resolve the held part's fatigue component. Returns comp, name (or nil after
-- messaging the user about why nothing's there). When an instance has more than
-- one matching component, prefer one whose max threshold is populated — some
-- duplicates read 0/0 and would otherwise be picked at random by scan order.
local function ResolveHeldComponent()
    local instance = GetHandInstance()
    if not instance then return nil end

    local name = ItemDisplayName(instance)
    local matches = FindFatigueComponents(instance)
    if #matches == 0 then
        msg:feedback(name .. " has no fatigue (not an aging car part, or its part actor isn't loaded).")
        return nil
    end

    local chosen = matches[1]
    for _, c in ipairs(matches) do
        local v = ReadFatigueQuiet(c)
        if v and type(v.max) == "number" and v.max > 0 then
            chosen = c
            break
        end
    end
    return chosen, name
end

-- Read all five fatigue out-params. Returns a table or nil (after messaging).
local function ReadFatigue(comp)
    local v = ReadFatigueQuiet(comp)
    if not v then
        msg:logErr("GetFatigue failed.")
    end
    return v
end

-- Show a readout toast.
local function ShowReadout(name, v)
    local pctText = (type(v.percent) == "number") and string.format("%.0f%%", v.percent * 100) or "?"
    local barText = (type(v.fatigue) == "number" and type(v.max) == "number")
        and string.format("%.1f / %.1f", v.fatigue, v.max) or "?"

    msg:feedback(string.format(
        "Fatigue of %s: %s (%s)",
        name, barText, pctText), 12.0)
end

-- ============================================================
-- Handlers
-- ============================================================

local function HandleGet()
    local comp, name = ResolveHeldComponent()
    if not comp then return true end
    local v = ReadFatigue(comp)
    if v then ShowReadout(name, v) end
    return true
end

local function HandleSet(args)
    local value = tonumber(args[1])
    if not value then
        msg:alert("Usage: fatigue set <number>")
        return true
    end
    local comp, name = ResolveHeldComponent()
    if not comp then return true end

    local ok, err = pcall(function() comp:SetFatigue(value) end)
    if not ok then
        msg:logErr("SetFatigue failed: " .. tostring(err))
        return true
    end

    local v = ReadFatigue(comp)
    if v then ShowReadout(name, v) end
    return true
end

local function HandleAdd(args)
    local delta = tonumber(args[1])
    if not delta then
        msg:alert("Usage: fatigue add <number> (negative to subtract)")
        return true
    end
    local comp, name = ResolveHeldComponent()
    if not comp then return true end

    local ok, err = pcall(function() comp:AddFatigue(delta) end)
    if not ok then
        msg:logErr("AddFatigue failed: " .. tostring(err))
        return true
    end

    local v = ReadFatigue(comp)
    if v then ShowReadout(name, v) end
    return true
end

local function HandleAge()
    local comp, name = ResolveHeldComponent()
    if not comp then return true end

    local v = ReadFatigue(comp)
    if not v then return true end
    if type(v.max) ~= "number" then
        msg:logErr("Could not read the max fatigue threshold.")
        return true
    end

    -- Drive fatigue up to the threshold via the accrual path (AddFatigue),
    -- which runs the game's max check and should fire MSG_MaxFatigue so the
    -- part ages natively. Nudge a hair over to be safe.
    local current = (type(v.fatigue) == "number") and v.fatigue or 0
    local delta = v.max - current
    if delta < 0 then delta = 0 end

    local ok, err = pcall(function() comp:AddFatigue(delta + 0.01) end)
    if not ok then
        msg:logErr("AddFatigue failed: " .. tostring(err))
        return true
    end

    msg:logInfo("Aged " .. name .. " — fatigue driven to threshold, the game should now roll its age effect.")
    local v2 = ReadFatigue(comp)
    if v2 then ShowReadout(name, v2) end
    return true
end

-- ============================================================
-- Global fatigue rate (UDrivingGameUserSettings.FatigueRateScale)
-- ============================================================

local function GetUserSettings()
    local s = FindFirstOf("DrivingGameUserSettings")
    if not s or not s:IsValid() then
        msg:logErr("DrivingGameUserSettings not found.")
        return nil
    end
    return s
end

local function HandleRateGet()
    local s = GetUserSettings()
    if not s then return true end

    local rate, disabled
    pcall(function() rate = s.FatigueRateScale end)
    pcall(function() disabled = s.bDisableFatigueEffects end)

    msg:feedback(string.format(
        "Global fatigue rate: %s (1.0 = normal)\nFatigue effects disabled: %s",
        tostring(rate), tostring(disabled)), 10.0, "\n")
    return true
end

local function HandleRateSet(args)
    local value = tonumber(args[1])
    if not value then
        msg:alert("Usage: fatigue rate set <number> (1.0 = normal, 0 = no fatigue gain)")
        return true
    end
    local s = GetUserSettings()
    if not s then return true end

    local ok, err = pcall(function() s.FatigueRateScale = value end)
    if not ok then
        msg:logErr("Failed to set fatigue rate: " .. tostring(err))
        return true
    end

    local readback
    pcall(function() readback = s.FatigueRateScale end)
    msg:feedback("Global fatigue rate set to " .. tostring(readback))
    return true
end

-- Dev: dump EVERY fatigue component matching the held instance plus the global
-- fatigue settings, to the UE4SS console. Diagnoses the intermittent 0/0 caused
-- by a held item having two matching components (a populated manifestation one
-- and a 0/0 one) — the read picker prefers the populated one.
local function HandleDump()
    local instance = GetHandInstance()
    if not instance then return true end

    local name = ItemDisplayName(instance)
    print(LOG_PREPEND .. "[Fatigue] ---- dump: " .. name .. " (" .. tostring(PathOf(instance)) .. ") ----")

    -- Global custom-run settings (UDrivingGameUserSettings).
    local settings = FindFirstOf("DrivingGameUserSettings")
    if settings then
        local rate, disabled
        pcall(function() rate = settings.FatigueRateScale end)
        pcall(function() disabled = settings.bDisableFatigueEffects end)
        print(string.format("%s[Fatigue] global: FatigueRateScale=%s bDisableFatigueEffects=%s",
            LOG_PREPEND, tostring(rate), tostring(disabled)))
    else
        print(LOG_PREPEND .. "[Fatigue] global: DrivingGameUserSettings not found")
    end

    local matches = FindFatigueComponents(instance)
    print(LOG_PREPEND .. "[Fatigue] matching components: " .. #matches)
    for i, c in ipairs(matches) do
        local v = ReadFatigueQuiet(c) or {}
        print(string.format("%s[Fatigue]   [%d] %s", LOG_PREPEND, i, tostring(PathOf(c))))
        print(string.format("%s[Fatigue]       Fatigue=%s Max=%s IntervalSize=%s Pct=%s",
            LOG_PREPEND, tostring(v.fatigue), tostring(v.max),
            tostring(v.interval), tostring(v.percent)))
    end
    print(LOG_PREPEND .. "[Fatigue] ---- end dump ----")

    msg:feedback("Dumped " .. #matches .. " fatigue component(s) for " .. name .. " to the UE4SS console.")
    return true
end

-- ============================================================
-- Command registration
-- ============================================================

local cmd = cm.MANAGER:register(
    "fatigue",
    {
        description = "Commands to manipulate the held part's fatigue.",
        detailed_description = "Fatigue is a hidden per-part 'bar' separate from Durability.\n" ..
                               "When it reaches its max threshold, the part's age status effect (worn/fragile/rusty/etc.) applies.\n" ..
                               "Not all parts have a fatigue component and not all parts with a fatigue component can fatigue.\n" ..
                               "Some commands will sometimes fail even if the held part has a fatigue component.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

cmd:branch(
    "get",
    {
        description = "Read the held part's fatigue, max threshold, and percent.",
        args_syntax = nil,
        flags_syntax = nil,
        aliases = "getfatigue"   -- `getfatigue` jumps straight to `fatigue get`
    },
    function(args, flags) return HandleGet() end
)

cmd:branch(
    "set",
    {
        description = "Set the held part's current fatigue directly, eg. 'fatigue set 100'.",
        args_syntax = "<value>",
        flags_syntax = nil
    },
    function(args, flags) return HandleSet(args) end
)

cmd:branch(
    "add",
    {
        description = "Add to the held part's current fatigue (use a negative value to subtract), eg. 'fatigue add 50'.",
        args_syntax = "<value>",
        flags_syntax = nil
    },
    function(args, flags) return HandleAdd(args) end
)

cmd:branch(
    "age",
    {
        description = "Drive the held part's fatigue to its threshold so the game ages it natively.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags) return HandleAge() end
)

local cmd_rate = cmd:branch(
    "rate",
    {
        description = "Read or set the GLOBAL fatigue rate multiplier (UDrivingGameUserSettings.FatigueRateScale). Affects every part. 1.0 = normal.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

cmd_rate:branch(
    "get",
    {
        description = "Show the global fatigue rate multiplier and whether fatigue effects are disabled.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags) return HandleRateGet() end
)

cmd_rate:branch(
    "set",
    {
        description = "Set the global fatigue rate multiplier, eg. 'fatigue rate set 2' (double) or 'fatigue rate set 0' (freeze).",
        args_syntax = "<value>",
        flags_syntax = nil
    },
    function(args, flags) return HandleRateSet(args) end
)

-- Dev: dump all fatigue components + global fatigue settings for the held item.
cm.cmd_debug:branch(
    "dbg_fatiguedump",
    {
        description = "Dump every fatigue component matching the held item, plus global FatigueRateScale/bDisableFatigueEffects, to the UE4SS console (dev).",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags) return HandleDump() end
)
