-- ============================================================
-- bookmarks: Save and load game state bookmarks.
-- Bookmarks stored in Mods/PDCmdMod/Scripts/bookmarks/
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("Bookmark")

local GAME_BMK = "../../../PenDriverPro/Content/Bookmarks/BookMark.bmk"
local BMK_DIR = "../../../PenDriverPro/Content/Bookmarks/"
local RESERVED = "bookmark"

local function GetPath(name)
    return BMK_DIR .. name .. ".bmk"
end

local function IsReserved(name)
    return name:lower() == RESERVED
end

local function CopyFile(src, dst)
    local f = io.open(src, "r")
    if not f then return false, "Cannot read: " .. src end
    local content = f:read("*a")
    f:close()
    local d = io.open(dst, "w")
    if not d then return false, "Cannot write: " .. dst end
    d:write(content)
    d:close()
    return true
end

local function GetSGM()
    local sgm = FindFirstOf("BP_SaveGameManager_C")
    if not sgm then return nil end
    return sgm
end

local function ValidateName(name)
    if not name or name == "" then
        return false, "Name cannot be empty"
    end
    if IsReserved(name) then
        return false, "'" .. name .. "' is reserved by the game"
    end
    -- No path traversal
    if name:find("%.%.") or name:find("[/\\]") then
        return false, "Name cannot contain path characters"
    end
    -- No special characters that would break filenames
    if name:find('[<>:"|%?%*]') then
        return false, "Name contains invalid characters"
    end
    -- Reasonable length
    if #name > 64 then
        return false, "Name too long (max 64 characters)"
    end
    return true
end

local cmd_bmk = cm.MANAGER:register(
    "bookmark",
    {
        description = "Make and load bookmarks.",
        detailed_description = "Bookmarks are alternate, non compressed and named save states.\n" ..
                               "Loading or making a bookmark will stop auto-saving (of any sort, including exiting junctions) until you manually save your game.\n" ..
                               "Not recommended for purposes other than data mining.",
        args_syntax = nil,
        flags_syntax = nil,
        aliases = { "bmk" }
    },
    nil
)

-- make
cmd_bmk:branch(
    "make",
    {
        description = "Create a named bookmark of the current game state.",
        detailed_description = "Makes a named bookmark of the current game state. Bookmarks are stored in PenDriverPro/Content/Bookmarks/.\n" ..
                               "Loading or making a bookmark will stop auto-saving (of any sort, including exiting junctions) until you manually save your game.",
        args_syntax = "<name>",
        aliases = { "bmkm", "bmks" }
    },
    function(args, flags)
        local name = args[1]
        if not name then
            msg:alert("Bookmark not found", "Usage: debug bmk make <name>")
            return true
        end
        local is_valid, err = ValidateName(name)
        if not is_valid then
            msg:alert("Invalid name", "This name is not allowed: " .. err)
            return true
        end

        local sgm = GetSGM()
        if not sgm then
            msg:logErr("SaveGameManager not found")
            return true
        end

        -- Tell game to write BookMark.bmk
        local ok, err = pcall(function()
            sgm["DbgActEvt_MakeBookmark \"bookmark\"_Execute"](sgm)
        end)
        if not ok then
            msg:alert("Cannot create bookmark", "MakeBookmark failed:\n" .. uim.wrapText(err), uim.TIME.PROBLEM, "\n")
            return true
        end

        -- Copy to named file
        local ok2, err2 = CopyFile(GAME_BMK, GetPath(name))
        if not ok2 then
            msg:alert("Cannot save bookmark", "Failed to save:\n" .. uim.wrapText(err2), uim.TIME.PROBLEM, "\n")
            return true
        end

        msg:feedback("Bookmark saved as '" .. name .. "'")
        return true
    end
)

-- load
cmd_bmk:branch(
    "load",
    {
        description = "Load a named bookmark.",
        detailed_description = "Loads a bookmark of the current game state. Bookmarks are stored in PenDriverPro/Content/Bookmarks/.\n" ..
                               "Loading or making a bookmark will stop auto-saving (of any sort, including exiting junctions) until you manually save your game." ..
                               "Note bookmarks are manually renamed to BookMark.bmk which the game searches for.",
        args_syntax = "<name>",
        aliases = { "bmkl" }
    },
    function(args, flags)
        local name = args[1]
        if not name then
            msg:alert("Bookmark name not specified", "Usage: debug bmk load <name>")
            return true
        end
        if IsReserved(name) then
            msg:alert("Invalid name", "'" .. name .. "' is reserved by the game")
            return true
        end

        -- Check file exists
        local f = io.open(GetPath(name), "r")
        if not f then
            msg:alert("Bookmark not found", "Bookmark not found: " .. name)
            return true
        end
        f:close()

        -- Copy to BookMark.bmk
        local ok, err = CopyFile(GetPath(name), GAME_BMK)
        if not ok then
            msg:alert("Cannot copy bookmark", "Failed to copy:\n" .. uim.wrapText(err), uim.TIME.PROBLEM, "\n")
            return true
        end

        local sgm = GetSGM()
        if not sgm then
            msg:logErr("SaveGameManager not found")
            return true
        end

        local ok2, err2 = pcall(function()
            sgm["DbgActEvt_LoadBookmark \"bookmark\"_Execute"](sgm)
        end)
        if not ok2 then
            msg:alert("Failed to load bookmark", "LoadBookmark failed:\n" .. uim.wrapText(err2), uim.TIME.PROBLEM, "\n")
            return true
        end

        msg:feedback("Loaded bookmark '" .. name .. "'")
        return true
    end
)

-- list
cmd_bmk:branch(
    "list",
    { description = "List all saved bookmarks." },
    function(args, flags)

        local names = {}
        local ok, result = pcall(function()
            local p = io.popen('dir "' .. BMK_DIR .. '" /b 2>nul')
            if not p then return nil end
            local content = p:read("*a")
            p:close()
            return content
        end)

        if not ok or not result or result == "" then
            msg:feedback("You have no bookmarks.")
            return true
        end

        for entry in result:gmatch("([^\r\n]+)") do
            if entry:match("%.bmk$") and entry ~= "BookMark.bmk" then
                table.insert(names, (entry:gsub("%.bmk$", "")))
            end
        end

        if #names == 0 then
            msg:feedback("You have no bookmarks.")
            return true
        end
        if #names < 15 then
            msg:feedback("You have " .. #names .. " bookmarks:\n  " .. table.concat(names, "\n  "), uim.TIME.PROBLEM, "\n")
        else
            msg:feedback(uim.wrapText("You have " .. #names .. " bookmarks: " .. table.concat(names, ", ")))
        end
        return true
    end
)

-- delete
cmd_bmk:branch(
    "delete",
    {
        description = "Delete a named bookmark.",
        detailed_description = "Deletion is permanant and there is no confirmation prompt. Use with caution!",
        args_syntax = "<name>"
    },
    function(args, flags)
        local name = args[1]
        if not name then
            msg:alert("Bookmark name not specified", "Usage: debug bmk delete <name>")
            return true
        end
        local is_valid, err = ValidateName(name)
        if not is_valid then
            msg:alert("Invalid name", err)
            return true
        end

        local path = GetPath(name)
        local f = io.open(path, "r")
        if not f then
            msg:alert("Bookmark not found", uim.wrapText("Bookmark not found: " .. name))
            return true
        end
        f:close()

        local ok, err = pcall(function()
            os.remove(path)
        end)
        if not ok then
            msg:alert("Cannot delete bookmark", "Delete failed:\n" .. uim.wrapText(err), uim.TIME.PROBLEM, "\n")
            return true
        end

        msg:feedback("Deleted bookmark '" .. name .. "'")
        return true
    end
)
