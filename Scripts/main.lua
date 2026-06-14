print("[PDCmdMod] Mod loading!")

local uim = require("uimanager")
local cm = require("commandmanager")

local msg = uim.newMessenger("Main")

require("give")
require("deletehand")
require("unlocklogs")
require("statuseffects")
require("spawnactor")
require("test")
require("event")
require("photo")
require("noborders")
require("iwdebug")
require("dlcgarage")
require("bookmarks")
require("expeditions")
require("loadbutton")
require("tp")
require("fatigue")


local function HandleIntroduction(mode)
    local message = [[Welcome to PDCmdMod by Perru (@perru_ on discord). Run 'pdcmdmod credits" to see full credits!
Open the command line by pressing F10. This message can be viewed again by running the command 'pdcmdmod'.
 
Run 'pdcmdmod list [page]' to explore the command list alongside their description.
Run 'pdcmdmod shortlist' to see a short list of every command in PDCmdMod.
Run 'pdcmdmod help [command ...]' to get a command's help. It works on any command and subcommand.
 
About the command system: when an argument must contain spaces, you can use quotes to wrap it as a single argument. Example: 'give name "Scrap Metal" 5'.
Tip: you can use FModel to browse through game files (in order to get pathes for different commands), but is not required to use core features of this mod.
 
This project is under the MIT license. A copy has been included in the LICENSE file.]]

    msg:feedback(message, uim.TIME.HELP, "\n")
end


local function HandleShortlist(mode)
    local commands = cm.MANAGER:commands()
    local names = {}

    for _, command in ipairs(cm.MANAGER:commands()) do
        table.insert(names, command.name:upper())
    end

    local result = table.concat(names, ", ")

    uim.sendMessage("Main", "Commands from PDCmdMod by Perru (@perru_ on discord) (short list): \n\t" .. result .. "\nTip: run 'pdcmdmod help <command> [subcommands/arguments...]' to get more information.", mode, 30.0, true)
end


-- local function HandleList(mode, page, ue4ssprint)

--     -- INIT
--     local commands = cm.MANAGER:commands()
--     local sortedCommands = {table.unpack(commands)}
--     table.sort(sortedCommands, function(a, b) return a.name < b.name end)

--     local MESSAGE_DURATION = 30.0
--     local ENTRIES_PER_PAGE = 5
--     local totalPages = math.ceil(#commands / ENTRIES_PER_PAGE)

--     -- GET FUNCTION  LIST
--     local displayedCommands = {}
--     if page == nil or page < 0 or page > totalPages then
--         uim.sendMessage("Main", "Invalid page number. Give a page between 1 and " .. tostring(totalPages) .. ".", mode, 8.0, true)  -- Allow page 0 as 'see all'
--     else
--         for i, command in ipairs(sortedCommands) do
--             local entryPage = math.ceil(i / ENTRIES_PER_PAGE)
--             if page == 0 or entryPage == page then
--                 table.insert(displayedCommands, command)
--             end
--         end
--     end

--     -- DISPLAY
--     local HEADER = "Commands from PDCmdMod by Perru (@perru_ on discord):\n  Help syntax: <mandatory> [optional]. Ellipsis means multiple/unknown subcommands/arguments.\n "
--     if ue4ssprint then
--         local msg = HEADER
--         for i = 1, #displayedCommands do
--             local command = displayedCommands[i]
--             msg = msg .. "  " .. command:get_usage(command.description ~= nil) .. "\n"
--         end
--         if page ~= 0 then
--             msg = ("\t"):rep(6) .. "[ PAGE " .. page .. " OF " .. totalPages .. " ]\n" .. msg
--         end
--         print("[PDCmdMod] [Main] " .. msg)
--     else
--         if page ~= 0 then
--             uim.sendMessage("Main", ("\t"):rep(6) .. "[ PAGE " .. page .. " OF " .. totalPages .. " ]", mode, MESSAGE_DURATION, true)
--         end
--         -- Go in reverse order because sendMessage on CHATLIKE is a queue
--         for i = #displayedCommands, 1, -1 do
--             local command = displayedCommands[i]
--             uim.sendMessage("Main", command:get_usage(command.description ~= nil), mode, MESSAGE_DURATION)
--         end
--         uim.sendMessage("Main", HEADER, mode, MESSAGE_DURATION, true)
--     end

-- end

local lastHelpMessage = nil

local function HandleList(page, logsOnly)
    -- page == nil → showall

    local ENTRIES_PER_PAGE = 5

    local commands = cm.MANAGER:commands()
    local sortedCommands = {table.unpack(commands)}
    table.sort(sortedCommands, function(a, b) return a.name < b.name end)

    local displayedCommands = {}
    local totalPages = math.ceil(#commands / ENTRIES_PER_PAGE)
    if page == nil then
        for i, command in ipairs(sortedCommands) do
            table.insert(displayedCommands, command)
        end
    elseif page < 0 or page > totalPages then
        uim.sendMessage("Main", "Invalid page number. Give a page between 1 and " .. tostring(totalPages) .. ".", mode, 8.0, true)  -- Allow page 0 as 'see all'
    else
        for i, command in ipairs(sortedCommands) do
            local entryPage = math.ceil(i / ENTRIES_PER_PAGE)
            if page == 0 or entryPage == page then
                table.insert(displayedCommands, command)
            end
        end
    end

    local message = "Commands from PDCmdMod by Perru (@perru_ on discord):<snl>" ..
                    "Help syntax: <mandatory> [optional]. Ellipsis means multiple/unknown subcommands/arguments<snl>" ..
                    " <snl>"
    
    for i, command in ipairs(displayedCommands) do
        message = message .. command:get_usage(command.description ~= nil) .. "<snl>"
    end

    if page ~= nil then -- nil → shortlist
        message = message .. " <snl>" .. ("\t"):rep(6) .. "[ PAGE " .. page .. " OF " .. totalPages .. " ]"
    end

    if logsOnly then
        message = message:gsub("<snl>", "\n")
        msg:logInfo(message)
    else
        if lastHelpMessage ~= nil and not lastHelpMessage:isExpired() then
            lastHelpMessage:setText(message)
            lastHelpMessage:setDuration(uim.readTime(message, uim.TIME.HELP))
        else
            lastHelpMessage = msg:feedback(message, uim.readTime(message, uim.TIME.HELP), "<snl>")
        end
    end
end

local function HandleCredits(mode)
    uim.sendMessage("Main", "PDCmdMod by Perru (@perru_ on discord).\n" ..
                            "This mod is available on github: https://github.com/MrPerruche/PDCmdMod\n \n" ..
                            "Thanks to Shruc for the expedition setlevel command."
    , mode, 15.0, true)
end


-- -------------------------------------------------------------
-- -------------------------------------------------------------
-- -------------------------------------------------------------

cmd_help = cm.MANAGER:register(
    "pdcmdmod",
    {
        description = "Show this message",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        HandleIntroduction(uim.MessageTypes.CHATLIKE)
        return true
    end
)

cmd_help:branch(
    "shortlist",
    {
        description = "Show a short list of every command in PDCmdMod. Run 'pdcmdmod help <command>' for details on a specific command.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        HandleShortlist(uim.MessageTypes.CHATLIKE)
        return true
    end
)

cmd_help:branch(
    "list",
    {
        description = "Show a paginated list of every command in PDCmdMod alongside their description. Run 'pdcmdmod shortlist' for a non-paginated short list.",
        args_syntax = "[page]",
        flags_syntax = "--showall, --ue4ssprint"
    },
    function(args, flags)
        local page = tonumber(args[1]) or 1
        if flags and flags["showall"] then
            page = nil
        end
        HandleList(page, flags and flags["ue4ssprint"])
        return true
    end
)

cmd_help:branch(
    "help",
    {
        description = "Do you need help with the help command? Do not worry. It's gonna be fine.",
        args_syntax = "<command> [subcommands and arguments...]",
        flags_syntax = nil,
        aliases = "pdh"
    },
    function(args, flags)

        if #args == 0 then
            cmd_help:show_help()
            return true
        end

        -- Support:
        --   help give name
        --   help "give name"
        if #args == 1 then
            local split = {}

            for token in args[1]:gmatch("%S+") do
                table.insert(split, token)
            end

            args = split
        end

        local node = cm.MANAGER:find(args)

        if not node then
            uim.sendMessage(
                "Help",
                ("Unknown command: %s"):format(table.concat(args, " ")),
                uim.MessageTypes.ALERT
            )
            return false
        end

        node:show_help()
        return true
    end
)

cmd_help:branch(
    "credits",
    {
        description = "Show credits for this mod.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        HandleCredits(uim.MessageTypes.CHATLIKE)
        return true
    end
)

-- Expire all live feedback toasts. Aliases: 'pdcmdmod clear', 'clear', 'cls', 'clr'.
local function HandleClear()
    local n = uim.clearActive()
    print("[Main] Cleared " .. tostring(n) .. " active message(s)")
    return true
end

cmd_help:branch(
    "clear",
    {
        description = "Clear all active on-screen feedback messages.",
        args_syntax = nil,
        flags_syntax = nil,
        aliases = { "clear", "cls", "clr" }
    },
    function(args, flags)
        return HandleClear()
    end
)

--[[local helpEntries = {
    {cmdname = "deletehand", command="deletehand", description="Deletes the item currently in your hand. Only works on droppable items.", hasHelp=false},
    {cmdname = "event", command="event <force/positive/debug/help> [args...]", description="Trigger events. 'force' and 'positive' are specific functions while 'debug' searches DbgActEvt functions.", hasHelp=true},
    {cmdname = "give", command="give <fullpath/path/name/display/help/tips> [args...]", description="Gives an item. Run 'give help' to learn more about this command.", hasHelp=true},
    {cmdname = "pdcmdmod", command="pdcmdmod [page/'short']", description="Show this message", hasHelp=false},
    {cmdname = "photo", command="photo <speed/rot/limits/preset/reset> [args...]", description="Photomode camera controls. Run 'photo help' to learn more about this command.", hasHelp=true},
    {cmdname = "spawn", command="spawn <asset_path>", description="Spawns an actor of the specified class near the player. eg. /Game/Gameplay/Hazards/Landmine/BP_Hazard_Landmine", hasHelp=false},
    {cmdname = "toggleborders", command="toggleborders", description="Toggle invisible and instability walls. The game will still tp you if you exit the map.", hasHelp=false},
    {cmdname = "unlocklogs", command="unlocklogs <all/id/name/help> [args...]", description="Unlock logbook entries. Run 'unlocklogs help' to learn more about this command.", hasHelp=false},
    {cmdname = "widget", command="widget <open/fullpath/close/closeall/list/help> [args...]", description="Spawn and manage (debug) widgets. Run 'widget help' to learn more about this command.", hasHelp=true},
}


local function HandleHelp(mode, page, secrets)
    -- PD shows in reverse order.
    if secrets then
        -- uim.sendMessage("Main", "Debug commands from PDCmdMod (MAY CRASH YOUR GAME OR BRICK YOUR SAVE!)\n"..
        --     "No debug commands yet, that are worth noting at least. How boring"
        --     , mode, 20.0, true
        -- )
    end

    local entriesPerPage = 5
    local totalPages = math.ceil(#helpEntries / entriesPerPage)

    if page ~= 0 then
        uim.sendMessage("Main", ("\t"):rep(6) .. "[ PAGE " .. page .. " OF " .. totalPages .. " ]\t'pdcmdmod short' for short list", mode, 30.0, true)
        uim.sendMessage("Main", "", mode, 30.0)
    end

    if page == 0 then  -- Page 0: show all regardless of length
        for i = #helpEntries, 1, -1 do
            local entry = helpEntries[i]
            uim.sendMessage("Main", "  " .. entry.command:upper() .. "\n    " .. entry.description .. "\n", mode, 30.0)
        end
    else
        for i = #helpEntries, 1, -1 do
            local entry = helpEntries[i]
            local entryPage = math.ceil(i / entriesPerPage)
            if entryPage == page then
                uim.sendMessage("Main", "  " .. entry.command:upper() .. "\n    " .. entry.description .. "\n", mode, 30.0)
            end
        end
    end
    uim.sendMessage("Main", "", mode, 30.0)
    uim.sendMessage("Main", "Commands from PDCmdMod by Perru (@perru_ on discord):", mode, 30.0)
    -- uim.sendMessage("Main", "Help for PDCmdMod by Perru (@perru_ on discord):\n"..
    --     "  give ...\n"..
    --     "    Gives an item. See 'give help' for details and usage info.\n"..
    --     "  deletehand\n"..
    --     "    Deletes the item currently in your hand. Only works on droppable items.\n"..
    --     "  unlocklogs ... - Unlock logbook entries. Use 'unlocklogs help' for details.\n"..
    --     "    Unlock logbook entries. See 'unlocklogs help' for details and usage info.\n"..
    --     "  help\n"..
    --     "    Show this message"
    -- , mode, 20.0, true)

end


local function HandleHelpShort(mode)

    local MAX_LINE_LENGTH = 180
    local lineChars = 0
    local result = ""

    for _, entry in ipairs(helpEntries) do
        local separator = ", "
        if result == "" then
            separator = ""
        elseif lineChars + entry.cmdname:len() > MAX_LINE_LENGTH then
            separator = ",\n"
            lineChars = 0
        end
        
        result = result .. separator .. entry.cmdname:upper()
        if entry.hasHelp then
            result = result .. " *"
        end
        lineChars = lineChars + separator:len() + entry.cmdname:len()

    end
    uim.sendMessage("Main", "Commands from PDCmdMod by Perru (@perru_ on discord) (* = has 'help' subcommand):\n" .. result, mode, 20.0, true)
end


RegisterConsoleCommandHandler("pdcmdmod", function(FullCommand, Parameters)

    if #Parameters == 1 then

        if Parameters[1]:lower() == "short" then
            HandleHelpShort(uim.MessageTypes.CHATLIKE)
            return true
        end

        local page = tonumber(Parameters[1])
        if page then
            HandleHelp(uim.MessageTypes.CHATLIKE, page, false)
        else
            HandleHelp(uim.MessageTypes.CHATLIKE, 1, false)
        end
    else
        HandleHelp(uim.MessageTypes.CHATLIKE, 1, false)
    end

    return true
end)

HandleHelpShort(uim.MessageTypes.LOGS)
]]