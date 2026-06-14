-- ============================================================
-- datastorage.lua: Simple persistent key-value storage.
-- Stores data as a plain Lua file that gets re-executed on load.
-- ============================================================

local cm = require("commandmanager")

local ds = {}

local SAVE_PATH = "Mods/PDCmdMod/Scripts/Data/savedata.lua"
local RESET_PATH = "Mods/PDCmdMod/Scripts/Data/savedata_default.lua"

local data = {}

-- Load data from disk on startup
local function Load()
    local f = io.open(SAVE_PATH, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    local chunk, err = load(content)
    if chunk then
        local ok, result = pcall(chunk)
        if ok and type(result) == "table" then
            data = result
        end
    end
end

-- Write data to disk
local function Save()
    local f = io.open(SAVE_PATH, "w")
    if not f then
        print("[DataStorage] ERROR: Could not open save file for writing. Please create file: " .. SAVE_PATH)
        return false
    end
    f:write("return {\n")
    for k, v in pairs(data) do
        local vStr
        if type(v) == "string" then
            vStr = string.format("%q", v)
        elseif type(v) == "boolean" then
            vStr = tostring(v)
        elseif type(v) == "number" then
            vStr = tostring(v)
        else
            -- skip unsupported types
            goto continue
        end
        f:write(string.format("    [%q] = %s,\n", k, vStr))
        ::continue::
    end
    f:write("}\n")
    f:close()
    return true
end

function ds.get(key, default)
    local v = data[key]
    if v == nil then return default end
    return v
end

function ds.set(key, value)
    data[key] = value
    Save()
end

function ds.delete(key)
    data[key] = nil
    Save()
end

-- Load on startup
Load()


local cmd = cm.cmd_debug:branch(
    "resetdata",
    {
        description = "Reset saved data",
        detailed_description = "Resets the saved data to the default state (settings contained in Scripts/Data/savedata_default.lua).",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local f = io.open(RESET_PATH, "r")
        if not f then return end
        local content = f:read("*a")
        f:close()
        local chunk, err = load(content)
        if chunk then
            local ok, result = pcall(chunk)
            if ok and type(result) == "table" then
                data = result
                Save()
            end
        end
        return true
    end
)


return ds