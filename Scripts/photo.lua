RegisterConsoleCommandHandler("phototestfdump", function(FullCommand, Parameters)
    local all = FindAllOf("BP_PhotomodeFreeCamera_C")
    if not all or #all == 0 then print("[Photo] Not in photo mode") return true end
    local cam = all[1]
    local path = cam:GetFullName():match("^%S+%s+(.+)$")
    
    -- Read floats around the suspected area
    for offset = 0x200, 0x300, 4 do
        local val = PDReadFloat(path, offset)
        print("[Photo] [0x" .. string.format("%X", offset) .. "] " .. tostring(val))
    end
    return true
end)
RegisterConsoleCommandHandler("phototestbdump", function(FullCommand, Parameters)
    local all = FindAllOf("BP_PhotomodeFreeCamera_C")
    if not all or #all == 0 then print("[Photo] Not in photo mode") return true end
    local cam = all[1]
    local path = cam:GetFullName():match("^%S+%s+(.+)$")
    
    -- Read floats around the suspected area
    PDDumpOffsets(path, 0x100, 0x400)
    return true
end)

-- ============================================================
-- photo: Photomode camera controls.
--
-- Usage:
--   photo speed <value>        -- Set movement speed (default 7.5)
--   photo interp <value>       -- Set interpolation speed (default 25, lower = smoother)
--   photo limits [on|off]      -- Toggle distance limit (default on)
--   photo reset                -- Reset all to defaults
--
-- Notes:
--   - Must be in photo mode for commands to take effect.
--   - Settings reset when exiting photo mode.
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("Photo")

local DEFAULTS = {
    MovementSensitivity = 7.5,
    RotationSensitivity = 1.0,
    bUseMaximumDistance = true,
    description = "Default photomode camera settings."
}

local PRESETS = {
    ["ultrafine"] = {MovementSensitivity=.25, RotationSensitivity=0.1, bUseMaximumDistance=false, description="Extremely fine control for millimeter accuracy."},
    ["fine"] = {MovementSensitivity=1, RotationSensitivity=0.5, bUseMaximumDistance=false, description="Fine control for precise positioning."},
    ["half"] = {MovementSensitivity=3.75, RotationSensitivity=1.0, bUseMaximumDistance=false, description="Half speed, no distance limit."},
    ["regular"] = {MovementSensitivity=7.5, RotationSensitivity=1.0, bUseMaximumDistance=false, description="Default photomode camera settings, without the distance limit."},
    ["double"] = {MovementSensitivity=15, RotationSensitivity=1.0, bUseMaximumDistance=false, description="Double speed, no distance limit."},
    ["fast"] = {MovementSensitivity=75, RotationSensitivity=1.0, bUseMaximumDistance=false, description="Fast movement for screenshots from a distance."},
    ["ultrafast"] = {MovementSensitivity=375, RotationSensitivity=1.0, bUseMaximumDistance=false, description="Extremely fast movement for screenshots across the map."},
    ["exp"] = {MovementSensitivity=375, RotationSensitivity=1.0, bUseMaximumDistance=true, description="Alias of 'expedition' preset."},
    ["expedition"] = {MovementSensitivity=375, RotationSensitivity=1.0, bUseMaximumDistance=true, description="Expeditions legal copy of the 'ultrafast' preset (limits on)."},
    ["ultraultrafast"] = {MovementSensitivity=10000, RotationSensitivity=1.0, bUseMaximumDistance=false, description="Have you lost your mind?"}
}


local function GetCamera()
    local all = FindAllOf("BP_PhotomodeFreeCamera_C")
    if not all or #all == 0 then return nil end
    for _, obj in ipairs(all) do
        local classOk = pcall(function() return obj:GetClass() end)
        if classOk then return obj end
    end
    return nil
end

-- RegisterConsoleCommandHandler("photo", function(FullCommand, Parameters)
--     if #Parameters == 0 then
--         HandleHelp(uim.MessageTypes.CHATLIKE)
--         return true
--     end

--     local cam = GetCamera()
--     if not cam then
--         HandleHelp(uim.MessageTypes.CHATLIKE)
--         return true
--     end

--     local mode = Parameters[1]:lower()

--     if mode == "speed" then
--         local val = tonumber(Parameters[2])
--         if not val then
--             HandleHelp(uim.MessageTypes.CHATLIKE)
--             return true
--         end
--         cam.MovementSensitivity = val
--         uim.sendMessage("Photo", "Movement speed set to " .. val, uim.MessageTypes.CHATLIKE)
    
--     elseif mode == "rot" then
--         local val = tonumber(Parameters[2])
--         if not val then
--             HandleHelp(uim.MessageTypes.CHATLIKE)
--             return true
--         end
--         cam.RotationSensitivity = val
--         uim.sendMessage("Photo", "Rotation speed set to " .. val, uim.MessageTypes.CHATLIKE)

--     elseif mode == "limits" then
--         local sub = Parameters[2] and Parameters[2]:lower()
--         if sub == "true" then
--             cam.bUseMaximumDistance = true
--             uim.sendMessage("Photo", "Distance limit enabled", uim.MessageTypes.CHATLIKE)
--         elseif sub == "false" then
--             cam.bUseMaximumDistance = false
--             uim.sendMessage("Photo", "Distance limit disabled", uim.MessageTypes.CHATLIKE)
--         else
--             -- toggle
--             cam.bUseMaximumDistance = not cam.bUseMaximumDistance
--             uim.sendMessage("Photo", "Distance limit: " .. (cam.bUseMaximumDistance and "true" or "false"), uim.MessageTypes.CHATLIKE)
--         end

--     elseif mode == "preset" then
--         local presetName = Parameters[2] and Parameters[2]:lower()
--         if presetName == "list" then
--             uim.sendMessage("Photo", "Available presets:", uim.MessageTypes.CHATLIKE)
--             for name, data in pairs(PRESETS) do
--                 uim.sendMessage("Photo", "  " .. name .. " - " .. data.description, uim.MessageTypes.CHATLIKE)
--             end
--             return true
--         elseif PRESETS[presetName] then
--             local preset = PRESETS[presetName]
--             cam.MovementSensitivity = preset.MovementSensitivity
--             cam.RotationSensitivity = preset.RotationSensitivity
--             cam.bUseMaximumDistance = preset.bUseMaximumDistance
--             uim.sendMessage("Photo", "Applied preset '" .. presetName, uim.MessageTypes.CHATLIKE)
--         else
--             uim.sendMessage("Photo", "Preset unknown", uim.MessageTypes.ALERT)
--             uim.sendMessage("Photo", "Use 'photo preset list' to see available presets.", uim.MessageTypes.CHATLIKE)
--             return true
--         end

--     elseif mode == "reset" then
--         cam.MovementSensitivity = DEFAULTS.MovementSensitivity
--         cam.RotationSensitivity = DEFAULTS.RotationSensitivity
--         cam.bUseMaximumDistance = DEFAULTS.bUseMaximumDistance
--         uim.sendMessage("Photo", "Reset to defaults", uim.MessageTypes.CHATLIKE)

--     else
--         uim.sendMessage("Photo", "Unknown mode", uim.MessageTypes.ALERT)
--         HandleHelp(uim.MessageTypes.CHATLIKE)
--     end

--     return true
-- end)


local cmd = cm.MANAGER:register(
    "photo",
    {
        description = "Go past the photomode border and edit camera speed.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

local cmd_speed = cmd:branch(
    "speed",
    {
        description = "Sets the movement speed.",
        args_syntax = "<speed>",
        flags_syntax = nil
    },
    function(args, flags)
        local cam = GetCamera()
        local val = tonumber(args[1])
        if val == nil then
            msg:alert("Invalid speed")
            return true
        end
        if cam then
            cam.MovementSensitivity = args[1]
            msg:feedback("Movement speed set to " .. args[1])
        end
        return true
    end
)

local cmd_rot = cmd:branch(
    "rot",
    {
        description = "Sets the rotation speed.",
        args_syntax = "<speed>",
        flags_syntax = nil
    },
    function(args, flags)
        local cam = GetCamera()
        local val = tonumber(args[1])
        if val == nil then
            msg:alert("Invalid speed")
            return true
        end
        if cam then
            cam.RotationSensitivity = args[1]
            msg:feedback("Rotation speed set to " .. args[1])
        end
        return true
    end
)

local cmd_limits = cmd:branch(
    "limits",
    {
        description = "Toggle distance limit.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local cam = GetCamera()
        if cam then
            cam.bUseMaximumDistance = not cam.bUseMaximumDistance
            msg:feedback("Distance limit: " .. (cam.bUseMaximumDistance and "enabled" or "disabled"))
        end
        return true
    end
)

local cmd_preset = cmd:branch(
    "mode",
    {
        description = "Apply preset settings (movement / limit settings).",
        args_syntax = "<preset>",
        flags_syntax = nil
    },
    function(args, flags)
        local cam = GetCamera()
        if cam then
            local presetName = args[1] and args[1]:lower()
            if PRESETS[presetName] then
                local preset = PRESETS[presetName]
                cam.MovementSensitivity = preset.MovementSensitivity
                cam.RotationSensitivity = preset.RotationSensitivity
                cam.bUseMaximumDistance = preset.bUseMaximumDistance
                msg:feedback("Applied preset '" .. presetName)
            else
                msg:alert("Preset unknown")
                msg:feedback("Use 'photo preset list' to see available presets.")
                return true
            end
        end
        return true
    end
)

local cmd_preset_list = cmd_preset:branch(
    "list",
    {
        description = "List available presets.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        msg:feedback("Available presets:")
        for name, data in pairs(PRESETS) do
            msg:feedback("  " .. name .. " - " .. data.description)
        end
        return true
    end
)

local cmd_reset = cmd:branch(
    "reset",
    {
        description = "Reset to defaults.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local cam = GetCamera()
        if cam then
            cam.MovementSensitivity = DEFAULTS.MovementSensitivity
            cam.RotationSensitivity = DEFAULTS.RotationSensitivity
            cam.bUseMaximumDistance = DEFAULTS.bUseMaximumDistance
            msg:feedback("Reset to defaults")
        end
        return true
    end
)
