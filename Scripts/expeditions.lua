local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("Expedition")


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
            msg:alert("Invalid command")
            return false  -- help
        end

        local pm = FindFirstOf("BP_ProgressionManager_C")
        if not pm then
            msg:alert("Save not loaded")
            return true
        end

        local ok, err = pcall(function()
            pm.CurrentExpeditionDifficulty = lvl
            pm.DisplayedExpeditionDifficulty = lvl
            msg:feedback("Set expedition level to " .. lvl)
        end)
        if not ok then
            msg:alert("Failed to set expedition level")
            msg:logErr("Error: " .. tostring(err))
        end
        return true
    end
)

-- ============================================================
-- expedition modifiers
-- ------------------------------------------------------------
-- Shows the modifiers the current expedition difficulty applies.
--
-- The game scales difficulty via RouteModifierAssets (ExpeditionTiers): each
-- active one carries human-readable FText (Name / ShortDescription) AND a set
-- of whiteboard operators. Every operator is an OP_Add (AddTo) or OP_Multiply
-- (MultiplyBy) keyed by a gameplay tag (e.g. an incoming-damage tag). We read
-- both: the raw add/multiply numbers per tag (aggregated) and the readable
-- descriptions (the "final" human-facing version).
-- ============================================================

local SOURCE = "Expedition"

-- "%.4g" but trims trailing noise; keeps it short for the toast.
local function fmtNum(v)
    if v == nil then return "?" end
    return (string.format("%.4g", v))
end

-- Class name token of a live UObject ("OP_Add", "OP_Multiply", ...).
local function classOf(obj)
    local ok, full = pcall(function() return obj:GetFullName() end)
    if ok and full then return full:match("^(%S+)") end
    return nil
end

-- Read one whiteboard operator -> { class, key, kind, value }.
-- kind is "add" (OP_Add.AddTo) / "mul" (OP_Multiply.MultiplyBy) /
-- "set" (OP_Set.SetTo) / "?" (unknown). value is a number or nil.
local function readOperator(op)
    local info = { class = classOf(op) or "?", key = nil, kind = "?", value = nil }

    -- Gameplay tag this operator targets (FGameplayTag.TagName is an FName).
    pcall(function()
        local s = op.Key.TagName:ToString()
        if s and #s > 0 then info.key = s end
    end)
    if info.key == nil then
        pcall(function()
            local s = tostring(op.Key.TagName)
            if s and #s > 0 and s ~= "nil" then info.key = s end
        end)
    end

    -- Reading a field that doesn't exist on this operator returns a garbage
    -- UObject wrapper, so only keep numeric reads.
    local function readNum(field)
        local v
        pcall(function() v = op[field] end)
        if type(v) == "number" then return v end
        return nil
    end

    local c = info.class
    if c:find("Add") then
        info.kind, info.value = "add", readNum("AddTo")
    elseif c:find("Multiply") then
        info.kind, info.value = "mul", readNum("MultiplyBy")
    elseif c:find("Set") then
        info.kind, info.value = "set", readNum("SetTo")
    else
        -- Unknown operator class: probe the known value fields.
        local a, m, s = readNum("AddTo"), readNum("MultiplyBy"), readNum("SetTo")
        if a then info.kind, info.value = "add", a
        elseif m then info.kind, info.value = "mul", m
        elseif s then info.kind, info.value = "set", s end
    end

    return info
end

-- Format a single operator's value, e.g. "+0.3", "x1.5", "= 2".
local function opStr(op)
    if op.value == nil then return (op.kind ~= "?" and op.kind or "?") .. "=?" end
    if op.kind == "add" then return (op.value >= 0 and "+" or "") .. fmtNum(op.value)
    elseif op.kind == "mul" then return "x" .. fmtNum(op.value)
    elseif op.kind == "set" then return "= " .. fmtNum(op.value)
    else return fmtNum(op.value) end
end

-- Combine an ordered list of operators on one tag into a single display string.
-- Same-kind stacks compress (sum of adds, product of muls, last set wins);
-- mixed kinds are replayed in order and marked approximate.
local function aggStr(ops)
    local add, mul, setv = 0, 1, nil
    local hasAdd, hasMul, hasSet, saw = false, false, false, false
    local eff = nil
    for _, op in ipairs(ops) do
        if op.value ~= nil then
            saw = true
            if op.kind == "add" then add = add + op.value; hasAdd = true; eff = (eff or 0) + op.value
            elseif op.kind == "mul" then mul = mul * op.value; hasMul = true; eff = (eff or 1) * op.value
            elseif op.kind == "set" then setv = op.value; hasSet = true; eff = op.value end
        end
    end
    if not saw then return "(no value)" end
    local kinds = (hasAdd and 1 or 0) + (hasMul and 1 or 0) + (hasSet and 1 or 0)
    if kinds == 1 then
        if hasSet then return "= " .. fmtNum(setv)
        elseif hasAdd then return (add >= 0 and "+" or "") .. fmtNum(add)
        else return "x" .. fmtNum(mul) end
    end
    return "~ " .. fmtNum(eff) .. " (mixed)"
end

-- "Key stat" filter for the focused view: gameplay scalars (damage/severity/
-- consumption *Scale, spawn *Density, *Rate). Keyword-based on purpose so new
-- tags are picked up without maintaining an allowlist; drops the route-shape /
-- biome / embark-restriction flags that aren't tunable multipliers.
local KEY_KEYWORDS = { "Scale", "Density", "Rate", "Weight" }
local function isKeyStat(tag)
    for _, kw in ipairs(KEY_KEYWORDS) do
        if tag:find(kw) then return true end
    end
    return false
end

-- Coerce a UE4SS array-ish value (native TArray, property array, or a wrapper
-- needing :get()) into a plain Lua list. Returns list, debugDescription.
local function arrayToList(arr)
    if arr == nil then return {}, "nil" end

    local okLen, n = pcall(function() return #arr end)
    if okLen and type(n) == "number" and n > 0 then
        local list = {}
        for i = 1, n do
            local v
            pcall(function() v = arr[i] end)
            if v ~= nil then table.insert(list, v) end
        end
        return list, "len=" .. n .. " read=" .. #list
    end

    -- Some out-params arrive wrapped; unwrap once via :get().
    local okGet, inner = pcall(function() return arr:get() end)
    if okGet and inner ~= nil and inner ~= arr then
        local list, desc = arrayToList(inner)
        return list, ":get -> " .. desc
    end

    return {}, "len=" .. tostring(n)
end

-- Read one RouteModifierAsset -> { name, shortDesc, ops = { ... } }.
local function readModifier(asset)
    local out = { name = nil, shortDesc = nil, ops = {} }

    local path
    pcall(function() path = asset:GetFullName():match("^%S+%s+(.+)$") end)
    if path then
        pcall(function() out.name = PDGetFText(path, "Name") end)
        pcall(function() out.shortDesc = PDGetFText(path, "ShortDescription") end)
        if out.name == nil or out.name == "" then
            out.name = path:match("([^%./]+)$")  -- fall back to asset name
        end
    end

    pcall(function()
        local ops = asset.Operators.Operations
        local n = #ops
        for i = 1, n do
            local op = ops[i]
            if op then table.insert(out.ops, readOperator(op)) end
        end
    end)

    return out
end

-- Gather everything once: difficulty header line + active modifier assets +
-- per-tag aggregated operators. Returns a table:
--   { ok, diffLine, reason?, mods, order (tag list), agg (tag -> {ops}) }
local function buildData()
    local pm = FindFirstOf("BP_ProgressionManager_C")
    if not pm then
        return { ok = false, diffLine = "Expedition modifiers", reason = "Save not loaded." }
    end

    local current, displayed, highest, overMax
    pcall(function() current = pm.CurrentExpeditionDifficulty end)
    pcall(function() displayed = pm.DisplayedExpeditionDifficulty end)
    pcall(function() highest = pm.HighestExpeditionDifficulty end)
    pcall(function() overMax = pm:GetOverMaxTierAmount() end)

    local diffLine = "Expedition difficulty: " .. tostring(current)
    if displayed ~= nil and displayed ~= current then diffLine = diffLine .. " (shown: " .. tostring(displayed) .. ")" end
    if overMax ~= nil and overMax ~= 0 then diffLine = diffLine .. " (+" .. tostring(overMax) .. " over max)" end
    if highest ~= nil then diffLine = diffLine .. " | highest reached: " .. tostring(highest) end

    msg:logInfo(("[modifiers] current=%s displayed=%s highest=%s overMax=%s")
        :format(tostring(current), tostring(displayed), tostring(highest), tostring(overMax)))

    -- Resolve active modifier assets. The BP function's array out-param is
    -- unreliable across the UE4SS boundary, so fall back to slicing the raw
    -- ExpeditionTiers property (exactly what the BP itself reads).
    local assets, source = {}, "none"

    pcall(function()
        local o = {}
        pm:GetActiveExpeditionDifficultyModifiers(o)
        local list, desc = arrayToList(o.Modifiers)
        msg:logInfo("[modifiers] GetActiveExpeditionDifficultyModifiers out: " .. desc)
        if #list > 0 then assets, source = list, "function" end
    end)

    if #assets == 0 then
        local tiers, tdesc = arrayToList(pm.ExpeditionTiers)
        msg:logInfo("[modifiers] ExpeditionTiers property: " .. tdesc)
        local count = #tiers
        if current ~= nil and current >= 0 and current < count then count = current end
        for i = 1, count do
            if tiers[i] then table.insert(assets, tiers[i]) end
        end
        if #assets > 0 then source = "ExpeditionTiers" end
    end

    msg:logInfo("[modifiers] resolved " .. #assets .. " asset(s) via " .. source)

    if #assets == 0 then
        return { ok = false, diffLine = diffLine,
                 reason = "No active difficulty modifiers found (source: " .. source .. ").\nSee UE4SS log for details." }
    end

    local mods = {}
    for i = 1, #assets do
        local m = readModifier(assets[i])
        table.insert(mods, m)
        msg:logInfo(("[modifiers]   [%d] %s ops=%d"):format(i, tostring(m.name), #m.ops))
    end

    -- Aggregate operators per tag, preserving first-seen order.
    local agg, order = {}, {}
    for _, m in ipairs(mods) do
        for _, op in ipairs(m.ops) do
            local k = op.key or "(unknown stat)"
            if not agg[k] then agg[k] = { ops = {} }; table.insert(order, k) end
            table.insert(agg[k].ops, op)
        end
    end

    return { ok = true, diffLine = diffLine, mods = mods, order = order, agg = agg }
end

-- Render a header (always shown) plus a paginated body. `page` is 1-based;
-- `moreCmd` is the command string suggested for the next page.
local LINES_PER_PAGE = 20
local function showPaged(headerLines, bodyLines, page, moreCmd)
    local total = math.max(1, math.ceil(#bodyLines / LINES_PER_PAGE))
    page = math.floor(tonumber(page) or 1)
    if page < 1 then page = 1 end
    if page > total then page = total end

    local out = {}
    for _, l in ipairs(headerLines) do table.insert(out, l) end
    if total > 1 then
        local nextPage = page < total and (page + 1) or 1
        table.insert(out, ("[ page %d / %d ]  next: %s %d"):format(page, total, moreCmd, nextPage))
    end
    if #bodyLines == 0 then table.insert(out, "  (nothing to show)") end
    local s = (page - 1) * LINES_PER_PAGE + 1
    for i = s, math.min(s + LINES_PER_PAGE - 1, #bodyLines) do
        table.insert(out, bodyLines[i])
    end

    msg:feedback(table.concat(out, "\n"), uim.TIME.HELP, "\n")
end

-- Strip the leading "WB." namespace for display.
local function shortTag(tag) return (tag:gsub("^WB%.", "")) end

local cmd_modifiers = cmd:branch(
    "modifiers",
    {
        description = "Show the stat modifiers applied by the current expedition difficulty.",
        detailed_description = "Aggregates the active difficulty's RouteModifierAssets into one effective value per stat tag (set =x, add +x, multiply *x). 'key' filters to gameplay scalars (damage/severity/consumption/density/rate); 'raw' dumps every operator; 'list' shows the active tier names. All paginated: pass a page number.",
        args_syntax = "[page]",
        flags_syntax = nil,
        aliases = nil
    },
    function(args, flags)
        local data = buildData()
        if not data.ok then
            msg:feedback(data.diffLine .. "\n" .. data.reason, uim.TIME.HELP, "\n")
            return true
        end
        local body = {}
        for _, k in ipairs(data.order) do
            table.insert(body, "  " .. shortTag(k) .. ": " .. aggStr(data.agg[k].ops))
        end
        showPaged({ data.diffLine, "Stat modifiers (" .. #data.order .. "):" }, body, args[1], "expedition modifiers")
        return true
    end
)

cmd_modifiers:branch(
    "key",
    {
        description = "Show only gameplay-scalar modifiers (damage/severity/consumption/density/rate).",
        detailed_description = "Filters the stat list to tags whose name contains Scale / Density / Rate / Weight. This is keyword-based (not a curated list), so e.g. pre-20 and post-20 (EndlessScaling) damage tags both appear; biome/route-shape/embark-restriction flags are dropped.",
        args_syntax = "[page]",
        flags_syntax = nil
    },
    function(args, flags)
        local data = buildData()
        if not data.ok then
            msg:feedback(data.diffLine .. "\n" .. data.reason, uim.TIME.HELP, "\n")
            return true
        end
        local body = {}
        for _, k in ipairs(data.order) do
            if isKeyStat(k) then
                table.insert(body, "  " .. shortTag(k) .. ": " .. aggStr(data.agg[k].ops))
            end
        end
        showPaged({ data.diffLine, "Key stat modifiers (" .. #body .. "):" }, body, args[1], "expedition modifiers key")
        return true
    end
)

cmd_modifiers:branch(
    "raw",
    {
        description = "Dump every whiteboard operator per active modifier (not aggregated).",
        args_syntax = "[page]",
        flags_syntax = nil
    },
    function(args, flags)
        local data = buildData()
        if not data.ok then
            msg:feedback(data.diffLine .. "\n" .. data.reason, uim.TIME.HELP, "\n")
            return true
        end
        local body = {}
        for _, m in ipairs(data.mods) do
            table.insert(body, "[" .. (m.name or "?") .. "]")
            if #m.ops == 0 then
                table.insert(body, "  (none)")
            else
                for _, op in ipairs(m.ops) do
                    table.insert(body, "  " .. (op.class or "?") .. "  " .. shortTag(op.key or "(unknown)") .. "  " .. opStr(op))
                end
            end
        end
        showPaged({ data.diffLine, "Raw operators:" }, body, args[1], "expedition modifiers raw")
        return true
    end
)

cmd_modifiers:branch(
    "list",
    {
        description = "List the active difficulty tier names and their descriptions.",
        args_syntax = "[page]",
        flags_syntax = nil
    },
    function(args, flags)
        local data = buildData()
        if not data.ok then
            msg:feedback(data.diffLine .. "\n" .. data.reason, uim.TIME.HELP, "\n")
            return true
        end
        local body = {}
        for _, m in ipairs(data.mods) do
            local line = "  " .. (m.name or "?")
            if m.shortDesc and m.shortDesc ~= "" then line = line .. " - " .. m.shortDesc end
            table.insert(body, line)
        end
        showPaged({ data.diffLine, "Active modifiers (" .. #data.mods .. "):" }, body, args[1], "expedition modifiers list")
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
            msg:feedback("This command will softlock you if you are not in the menu and must currently pick one of 3 rewoven hard drives.\nSave your game then run with flag --iknowwhatimdoing to reroll.\nExit then re-open the route planner to update offers.", uim.TIME.HELP, "\n")
            return true
        end

        local pm = FindFirstOf("BP_ProgressionManager_C")
        if not pm then
            msg:alert("Save not loaded")
            return true
        end

        local ok, err = pcall(function()
            pm:ClearAndGenerateNewExpeditions()
        end)
        if ok then
            msg:feedback("Expedition offerings rerolled")
        else
            msg:alert("Failed to reroll expeditions", nil, uim.TIME.PROBLEM)
            msg:logErr("Error: " .. tostring(err))
        end
        return true
    end
)
