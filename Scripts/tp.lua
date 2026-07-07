-- ============================================================
-- tp: Teleport car / player / photo-camera to a position.
--
-- Usage:
--   tp <car|player|cam> [x y z]  [--relative-to=<self|car|player|cam>]
--
--   Coordinates are per-axis. Each of x/y/z is either:
--     absolute   100      -> world coordinate on that axis
--     relative   ~10      -> base coordinate + 10 on that axis
--                ~        -> base coordinate + 0
--
--   The "base" for relative (~) axes is:
--     - the target's own current position           (default / --relative-to=self)
--     - the named target's position                 (--relative-to=car|player|cam)
--   Absolute axes ignore the base entirely.
--
--   With no coordinates but a --relative-to given, behaves as
--   `~ ~ ~` (teleports the target onto the relative-to target).
--
--   Examples:
--     tp player 100 200 300            -- absolute world position
--     tp car ~0 ~0 ~500                -- 500 units up from the car
--     tp player --relative-to=car      -- warp player onto the car
--     tp cam ~0 ~0 ~1000 --relative-to=player   -- 1000 above the player
--
-- Notes:
--   - cam targets BP_PhotomodeFreeCamera_C and only works in photo mode.
--   - Uses K2_SetActorLocation with bTeleport=true (hard teleport).
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("tp")

-- mode name -> function returning the live actor (or nil)
local TARGETS = {
    player = function() return FindFirstOf("PDP_MainCharacter_C") end,
    car    = function() return FindFirstOf("BP_PlayerCarNew_C") end,
    cam    = function()
        local cams = FindAllOf("BP_PhotomodeFreeCamera_C")
        return cams and cams[1] or nil
    end,
}

-- Human-readable reason an actor might be missing (used in errors).
local NOT_FOUND = {
    player = "Player not found.",
    car    = "Car not found.",
    cam    = "Camera not found. You must be in photo mode.",
}

local function GetLoc(actor)
    local ok, loc = pcall(function() return actor:K2_GetActorLocation() end)
    if not ok or not loc then return nil end
    local ok2, t = pcall(function() return { X = loc.X, Y = loc.Y, Z = loc.Z } end)
    if not ok2 then return nil end
    return t
end

local function SetLoc(actor, loc)
    local ok = pcall(function()
        actor:K2_SetActorLocation({ X = loc.X, Y = loc.Y, Z = loc.Z }, false, {}, true)
    end)
    return ok
end

-- Parse one coordinate token. Returns { rel = bool, val = number } or nil.
local function ParseCoord(tok)
    if tok:sub(1, 1) == "~" then
        local rest = tok:sub(2)
        if rest == "" then return { rel = true, val = 0 } end
        local n = tonumber(rest)
        if not n then return nil end
        return { rel = true, val = n }
    end
    local n = tonumber(tok)
    if not n then return nil end
    return { rel = false, val = n }
end

-- Shared teleport logic. `args` are the coord tokens (mode already consumed
-- by the subcommand). Returns a boolean suitable for the command handler.
local function DoTeleport(mode, args, flags)
    local target = TARGETS[mode]()
    if not target then
        msg:logErr(NOT_FOUND[mode])
        return true
    end

    -- --relative-to value (string), or nil if the flag was absent.
    local relTo = flags and flags["relative-to"]
    if relTo == true then
        msg:alert("--relative-to needs a value: self, car, player or cam.")
        return true
    end
    if relTo then
        relTo = tostring(relTo):lower()
        if relTo ~= "self" and not TARGETS[relTo] then
            msg:alert("Invalid --relative-to: " .. relTo)
            return true
        end
    end

    -- Resolve the coordinate spec (list of 3 {rel,val}).
    local coords
    if #args == 0 then
        if not relTo then
            msg:alert("No coordinates given. Provide 'x y z' or a --relative-to target.")
            return false  -- triggers help
        end
        coords = { { rel = true, val = 0 }, { rel = true, val = 0 }, { rel = true, val = 0 } }
    elseif #args == 3 then
        coords = {}
        for i = 1, 3 do
            local c = ParseCoord(args[i])
            if not c then
                msg:alert("Invalid coordinate: " .. tostring(args[i]))
                return true
            end
            coords[i] = c
        end
    else
        msg:alert("Expected 3 coordinates (x y z), got " .. #args .. ".")
        return false  -- triggers help
    end

    -- Do we need a base position? Yes if any axis is relative.
    local needBase = coords[1].rel or coords[2].rel or coords[3].rel
    local baseLoc
    if needBase then
        local baseActor
        if not relTo or relTo == "self" then
            baseActor = target
        else
            baseActor = TARGETS[relTo]()
            if not baseActor then
                msg:logErr("Relative-to " .. (NOT_FOUND[relTo] or "target not found."))
                return true
            end
        end
        baseLoc = GetLoc(baseActor)
        if not baseLoc then
            msg:logErr("Could not read the base position.")
            return true
        end
    end

    local axes = { "X", "Y", "Z" }
    local newLoc = {}
    for i = 1, 3 do
        local a = axes[i]
        if coords[i].rel then
            newLoc[a] = baseLoc[a] + coords[i].val
        else
            newLoc[a] = coords[i].val
        end
    end

    if SetLoc(target, newLoc) then
        msg:feedback(string.format("Teleported %s to (%.1f, %.1f, %.1f)",
            mode, newLoc.X, newLoc.Y, newLoc.Z))
    else
        msg:logErr("Teleport failed.")
    end
    return true
end

local cmd_tp = cm.MANAGER:register(
    "tp",
    {
        description = "Teleport the player, car or camera.",
        detailed_description = "Teleport the player, car or camera to a specific position. 1 meter is 100 units.\n" ..
                               "Coordinates can be absolute or relative (~ prefix).\n" ..
                               "You may use --relative-to to specify the base for relative coordinates.\n" ..
                               "If you specify --relative-to, you may omit the coordinates to teleport the target onto the relative-to target.",
        args_syntax = "<car|player|cam> [x y z]",
        flags_syntax = "--relative-to=<self|car|player|cam>"
    },
    nil
)

cmd_tp:branch(
    "player",
    {
        description = "Teleport the player. eg. 'tp player ~0 ~0 ~500' (500 up).",
        args_syntax = "[x y z]",
        flags_syntax = "--relative-to=<self|car|player|cam>"
    },
    function(args, flags) return DoTeleport("player", args, flags) end
)

cmd_tp:branch(
    "car",
    {
        description = "Teleport the car. eg. 'tp car --relative-to=player' to bring it to you.",
        args_syntax = "[x y z]",
        flags_syntax = "--relative-to=<self|car|player|cam>"
    },
    function(args, flags) return DoTeleport("car", args, flags) end
)

cmd_tp:branch(
    "cam",
    {
        description = "Teleport the photomode camera (must be in photo mode).",
        args_syntax = "[x y z]",
        flags_syntax = "--relative-to=<self|car|player|cam>"
    },
    function(args, flags) return DoTeleport("cam", args, flags) end
)


-- ============================================================
-- dbg tpprobe: read-only discovery tool kept for future work.
-- Prints location get/set support for player/car/cam and lists
-- all pawns (to spot new/renamed vehicle classes).
-- ============================================================

local function FmtVec(v)
    if not v then return "nil" end
    local ok, s = pcall(function()
        return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
    end)
    return ok and s or "<unreadable>"
end

local function ClassNameOf(obj)
    local ok, n = pcall(function() return obj:GetFullName():match("^(%S+)") end)
    return ok and n or "?"
end

local function ProbeActor(label, actor)
    if not actor then
        print(string.format("[tpprobe] %-8s : not found", label))
        return
    end
    local loc = GetLoc(actor)
    print(string.format("[tpprobe] %-8s : class=%s loc=%s", label, ClassNameOf(actor), FmtVec(loc)))
    if loc then
        local ok1 = pcall(function()
            actor:K2_SetActorLocation({ X = loc.X, Y = loc.Y, Z = loc.Z }, false, {}, true)
        end)
        local ok2 = pcall(function()
            local r = actor:K2_GetActorRotation()
            actor:K2_TeleportTo({ X = loc.X, Y = loc.Y, Z = loc.Z }, { Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll })
        end)
        print(string.format("[tpprobe]            K2_SetActorLocation=%s K2_TeleportTo=%s",
            ok1 and "ok" or "ERR", ok2 and "ok" or "ERR"))
    end
end

cm.cmd_debug:branch(
    "tpprobe",
    {
        description = "Probe player/car/cam for location get/set support (dev).",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        print("[tpprobe] ---- begin ----")
        ProbeActor("player", TARGETS.player())
        ProbeActor("cam", TARGETS.cam())
        print("[tpprobe] -- pawns (look for the car) --")
        local seen = {}
        for _, p in ipairs(FindAllOf("Pawn") or {}) do
            local cls = ClassNameOf(p)
            if not seen[cls] then
                seen[cls] = true
                print(string.format("[tpprobe]   pawn class=%s loc=%s", cls, FmtVec(GetLoc(p))))
            end
        end
        print("[tpprobe] ---- end ----")
        msg:feedback("Probe done. See UE4SS console output.")
        return true
    end
)
