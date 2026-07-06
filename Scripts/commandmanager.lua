-- CommandSystem.lua
-- Tree-based command system for UE4SS mods.
-- Usage: local CM = require("CommandSystem")

local CommandSystem = {}
local uim = require("uimanager")

local msg = uim.newMessenger("Command")


-- ─────────────────────────────────────────────
-- Argument Parser
--
-- Supports:
--   bare words         →  hello
--   double-quoted str  →  "hello world"
--   single-quoted str  →  'hello world'
--   escape sequences   →  \" \' \n \t \\
--   boolean flags      →  --flag
--   value flags        →  --flag=value  or  --flag="spaced value"
--
-- Returns: args (array), flags (table)
-- ─────────────────────────────────────────────

local function SendUnknownError(cmd, err)
    msg:alert("Unknown command", "No command matches: " .. cmd)
    msg:logInfo("Error: " .. tostring(err))
end


local function out(msg)
    print("[CMD] " .. tostring(msg))
end

local function out_err(msg)
    print("[CMD ERR] " .. tostring(msg))
end

local function parse_escape(ch)
    if     ch == "n"  then return "\n"
    elseif ch == "t"  then return "\t"
    elseif ch == '"'  then return '"'
    elseif ch == "'"  then return "'"
    elseif ch == "\\" then return "\\"
    else                   return "\\" .. ch  -- unknown → pass through as-is
    end
end

local function parse_args(input)
    local args  = {}
    local flags = {}
    local i     = 1
    local len   = #input

    while i <= len do
        -- skip whitespace
        while i <= len and input:sub(i, i):match("%s") do i = i + 1 end
        if i > len then break end

        -- ── flag: --name  or  --name=value ──────────────────────────────────
        if input:sub(i, i + 1) == "--" then
            i = i + 2
            local key_start = i
            while i <= len and not input:sub(i, i):match("[%s=]") do i = i + 1 end
            local key = input:sub(key_start, i - 1)

            if key == "" then
                -- bare "--" with nothing after it; skip silently
            elseif input:sub(i, i) == "=" then
                i = i + 1  -- consume '='
                local val = ""
                if input:sub(i, i) == '"' then
                    i = i + 1
                    while i <= len do
                        local c = input:sub(i, i)
                        if     c == "\\" then val = val .. parse_escape(input:sub(i + 1, i + 1)); i = i + 2
                        elseif c == '"'  then i = i + 1; break
                        else                  val = val .. c; i = i + 1
                        end
                    end
                else
                    while i <= len and not input:sub(i, i):match("%s") do
                        val = val .. input:sub(i, i); i = i + 1
                    end
                end
                flags[key] = val
            else
                flags[key] = true  -- boolean flag
            end

        -- ── double-quoted string ─────────────────────────────────────────────
        elseif input:sub(i, i) == '"' then
            i = i + 1
            local token = ""
            while i <= len do
                local c = input:sub(i, i)
                if     c == "\\" then token = token .. parse_escape(input:sub(i + 1, i + 1)); i = i + 2
                elseif c == '"'  then i = i + 1; break
                else                  token = token .. c; i = i + 1
                end
            end
            table.insert(args, token)

        -- ── single-quoted string ─────────────────────────────────────────────
        elseif input:sub(i, i) == "'" then
            i = i + 1
            local token = ""
            while i <= len do
                local c = input:sub(i, i)
                if     c == "\\" then token = token .. parse_escape(input:sub(i + 1, i + 1)); i = i + 2
                elseif c == "'"  then i = i + 1; break
                else                  token = token .. c; i = i + 1
                end
            end
            table.insert(args, token)

        -- ── bare word ────────────────────────────────────────────────────────
        else
            local token = ""
            while i <= len and not input:sub(i, i):match("%s") do
                local c = input:sub(i, i)
                if c == "\\" then token = token .. parse_escape(input:sub(i + 1, i + 1)); i = i + 2
                else              token = token .. c; i = i + 1
                end
            end
            table.insert(args, token)
        end
    end

    return args, flags
end

-- ─────────────────────────────────────────────
-- Command Node
-- ─────────────────────────────────────────────

-- Register every alias of a node as a top-level console command that
-- jumps straight to that node. Works for top-level commands AND branches:
-- the alias is placed in the manager's root children and pointed at the
-- node, so dispatch resolves `alias <rest>` as `<node path> <rest>`.
-- (e.g. alias "bmkm" on the bookmark>make branch makes "bmkm x" act like
-- "bookmark make x".) Aliases never change a node's canonical path().
local function register_node_aliases(manager, node)
    local aliases = node.aliases
    if not aliases or not manager then return end
    if type(aliases) == "string" then aliases = { aliases } end
    for _, alias in ipairs(aliases) do
        manager._root.children[alias:lower()] = node
        RegisterConsoleCommandHandler(alias, function(full_input)
            local n = manager:dispatch(full_input)
            return n ~= nil
        end)
    end
end

local Command = {}
Command.__index = Command

-- Internal constructor — use Manager:register() or node:branch() instead.
local function new_node(name, opts, handler)
    return setmetatable({
        name         = name,
        description  = opts.description  or nil,  -- string: what this command does
        detailed_description = opts.detailed_description or nil,  -- string: longer help text, shown only when viewing this exact node's help
        args_syntax  = opts.args_syntax  or nil,  -- string: e.g. '<display name> [amount]'
        flags_syntax = opts.flags_syntax or nil,  -- string: e.g. '--silent, --count=<n>'
        aliases      = opts.aliases      or nil,  -- table|string: extra names that jump to this node
        handler      = handler,                   -- function(args, flags) or nil
        children     = {},                        -- name (lowercase) → Command node
        _parent      = nil,
    }, Command)
end

-- Register a child subcommand on this node.
-- opts is a table: { description, detailed_description, args_syntax, flags_syntax }  (all optional)
-- detailed_description is longer help text shown only when this exact node's help is viewed.
-- handler is a function(args, flags), or nil for intermediate branch nodes.
function Command:branch(name, opts, handler)
    assert(type(name) == "string" and name ~= "", "branch name must be a non-empty string")
    local child  = new_node(name, opts, handler)
    child._parent = self
    child._manager = self._manager
    self.children[name:lower()] = child
    register_node_aliases(self._manager, child)
    return child
end

-- Returns the full command path as a space-separated string, e.g. "give from_name".
function Command:path()
    local parts = {}
    local node  = self
    while node do
        if node.name ~= "__root__" then
            table.insert(parts, 1, node.name)
        end
        node = node._parent
    end
    return table.concat(parts, " ")
end

-- Walk tokens depth-first; returns (deepest matching node, index of first unmatched token).
function Command:_resolve(tokens, depth)
    -- print(
    --     "DEBUG RESOLVE",
    --     self.name,
    --     "depth=" .. tostring(depth),
    --     "token=" .. tostring(tokens[depth])
    -- )

    local child = self.children[(tokens[depth] or ""):lower()]

    if child then
        -- print("DEBUG FOUND CHILD", child.name)
        return child:_resolve(tokens, depth + 1)
    end

    -- print("DEBUG STOP AT", self.name)

    return self, depth
end

-- ─────────────────────────────────────────────
-- Manager
-- ─────────────────────────────────────────────

local Manager = {}
Manager.__index = Manager

function Manager.new()
    return setmetatable({
        _root = new_node("__root__", {}, nil),
    }, Manager)
end

-- Register a top-level command.
-- opts is a table: { description, detailed_description, args_syntax, flags_syntax }  (all optional)
-- detailed_description is longer help text shown only when this exact node's help is viewed.
-- handler is a function(args, flags), or nil for group nodes.
function Manager:register(name, opts, handler)
    -- print("DEBUG REGISTER MANAGER:", self)
    assert(type(name) == "string" and name ~= "", "command name must be a non-empty string")
    local cmd     = new_node(name, opts, handler)
    cmd._parent   = self._root
    cmd._manager  = self
    self._root.children[name:lower()] = cmd

    -- print("DEBUG REGISTERED:", name)

    -- for k, _ in pairs(self._root.children) do
    --     print("DEBUG ROOT CHILD:", k)
    -- end

    RegisterConsoleCommandHandler(name, function(full_input)
        -- print("DEBUG COMMAND INPUT:", tostring(full_input))
        local node, args, flags = CommandSystem.MANAGER:dispatch(full_input)
        return node ~= nil  -- return true if command was handled, false for "unknown command"
    end)

    register_node_aliases(self, cmd)

    return cmd
end


function Manager:find(tokens)
    local node = self._root

    for _, token in ipairs(tokens) do
        node = node.children[token:lower()]

        if not node then
            return nil
        end
    end

    return node
end


-- Dispatch a raw input string.
-- Returns the matched node and parsed (args, flags) so the caller can do whatever they want.
-- If no command is matched, returns nil.
function Manager:dispatch(input)
    -- print("DEBUG DISPATCH MANAGER:", self)
    if type(input) ~= "string" or input:match("^%s*$") then return nil end

    local raw_tokens = {}
    for tok in input:gmatch("%S+") do
        table.insert(raw_tokens, tok)
    end
    if #raw_tokens == 0 then return nil end

    -- print("DEBUG LOOKING FOR:", raw_tokens[1]:lower())

    for k, _ in pairs(self._root.children) do
        -- print("DEBUG AVAILABLE:", k)
    end

    local top = self._root.children[raw_tokens[1]:lower()]
    if not top then return nil, raw_tokens[1] end  -- caller handles "unknown command"

    local node, next_depth = top:_resolve(raw_tokens, 2)

    -- Re-join the unmatched tail and run the full parser over it
    -- so quoted strings and flags work correctly.
    local tail_parts = {}
    for idx = next_depth, #raw_tokens do
        table.insert(tail_parts, raw_tokens[idx])
    end
    local args, flags = parse_args(table.concat(tail_parts, " "))
    if args == nil then
        args = {}
    end
    if flags == nil then
        flags = {}
    end

    if node.handler then
        -- local ok, err = pcall(node.handler, args, flags)

        -- if not ok then
        --     SendUnknownError(input, err)
        -- end
        local success = node.handler(args, flags)
        if not success then
            node:show_help()
        end
    else
        node:show_help()
    end

    return node, args, flags
end

-- Returns an array of all top-level command nodes (for building help UIs etc.).
-- Aliases live in _root.children too (pointing at their target node), so skip
-- any entry that isn't a node's own canonical top-level registration: an alias
-- entry's key never matches its node's name, and branch aliases point at a node
-- whose parent isn't the root. This keeps aliases out of every list.
function Manager:commands()
    local list = {}
    for key, cmd in pairs(self._root.children) do
        if cmd._parent == self._root and cmd.name:lower() == key then
            table.insert(list, cmd)
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end


-- ─────────────────────────────────────────────
-- Help
-- ─────────────────────────────────────────────

function Command:get_usage(includeDescription)
    local usage = self:path()

    if self.args_syntax then
        usage = usage .. " " .. self.args_syntax
    elseif next(self.children) ~= nil then
        usage = usage .. " ..."
    end

    if self.flags_syntax then
        usage = usage .. "  Flags: " .. self.flags_syntax
    end
    
    if includeDescription and self.description then
        usage = usage:upper() .. "\n  " .. self.description .. "\n"
    end

    return usage
end


function ChildNameAndAliases(child)
    if not child.aliases then
        return child.name
    end
    
    aliases = type(child.aliases) == "string" and { child.aliases } or child.aliases
    return child.name .. " (" .. table.concat(aliases, ", ") .. ")"
end


function Command:show_help()

    local hasSubcommands = next(self.children) ~= nil
    local hasAliases = self.aliases ~= nil

    local message = tostring(self:get_usage(self.description ~= nil))

    -- Detailed description only ever shows for the node whose help is being
    -- viewed directly — never for the subcommands listed below it.
    if self.detailed_description then
        message = message .. "<snl>Full description:"
        for line in uim.wrapText(self.detailed_description):gmatch("[^\r\n]+") do
            message = message .. "<snl>  " .. line
        end
    end

    if hasAliases then
        local aliases = type(self.aliases) == "string" and { self.aliases } or self.aliases
        message = message .. "<snl>" .. uim.wrapText("Aliases: " .. table.concat(aliases, ", "))
    end

    if hasSubcommands then
        message = message .. "<snl>Subcommands:"

        local children = {}
        for _, child in pairs(self.children) do
            table.insert(children, child)
        end

        table.sort(children, function(a, b)
            return a.name < b.name
        end)

        local longest = 0
        for _, child in ipairs(children) do
            longest = math.max(longest, #ChildNameAndAliases(child))
        end

        for _, child in ipairs(children) do
            local spaces = math.max(16, longest + 4)
            message = message .. "<snl>" .. (("  %-" .. spaces .. "s %s")
                :format(
                    ChildNameAndAliases(child),
                    child.description or ""
                )
            )
        end
    end

    -- uim.sendMessage in reverse over the message stack so the top message appears first in the chat window
    msg:feedback(message, uim.TIME.HELP, "<snl>")
end


function Manager:show_help()
    out("Available commands:")

    local commands = self:commands()

    for _, cmd in ipairs(commands) do
        out(("  %-16s %s")
            :format(
                cmd.name,
                cmd.description or ""
            ))
    end
end

-- ─────────────────────────────────────────────
-- Module export
-- ─────────────────────────────────────────────

CommandSystem.MANAGER    = Manager.new()
CommandSystem.Manager    = Manager    -- for multiple-manager setups
CommandSystem.parse_args = parse_args -- exposed for testing

local cmd_debug = CommandSystem.MANAGER:register(
    "debug",
    {
        description = "Debug commands from the PDCmdMod used for development.",
        detailed_description = "These commands are not intended for you to use and may change or be removed at any time.\n" ..
                               "They may crash the game, corrupt your save or cause other issues.\n" ..
                               "Debug functions do not have any exclusive features. Any functionality they may offer are accessible via safer commands.",
        args_syntax = "<command> [subcommands and arguments...]",
        flags_syntax = nil,
        aliases = { "dbg" }
    },
    nil
)
CommandSystem.cmd_debug = cmd_debug

return CommandSystem
