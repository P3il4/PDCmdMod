-- NOTE: PDShowInventoryMessage is the alert at the top of the screen.
-- \n for newlines (despite having poor support)

local uim = {}

RegisterConsoleCommandHandler("toasttest", function(FullCommand, Parameters)
    local fm = FindFirstOf("BP_FeedbackManager_C")
    local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
    PDShowInventoryMessage("Gave 100x Rippling Quartz (IA_Resource_Rippling_Quartz)", fmPath)

    return true
end)


-- DATA AND ENUM STUFF

uim.MessageTypes = {
    ALERT = "alert",
    CHATLIKE = "chatlike",
    LOGS = "logs",
    ERR = "err"
}

show_info_logs = false
show_err_logs = true

LOG_PREPEND = "[PDCmdMod] "


-- ============================================================
-- Stream toast system
-- ============================================================

local streamInitialized = false
local streamBox = nil
local streamWidget = nil

-- OOP messaging layer state (see "Messenger / Message" section below).
-- Declared up here so ResetStream can flush the registry on map reload.
local DEFAULT_FEEDBACK_DURATION = 4.0
local activeMessages = {}  -- set: live feedback Message -> true

local function ResetStream()
    streamInitialized = false
    streamBox = nil
    streamWidget = nil

    -- Stream widgets go stale on map reload; drop every live Message handle so
    -- stale timers no-op and 'clear' won't poke dead widgets.
    for msg, _ in pairs(activeMessages) do
        msg._expired = true
    end
    activeMessages = {}
end

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    ResetStream()
end)

local function InitStream()
    if streamInitialized then return true end

    -- Find live FadingBox
    local boxes = FindAllOf("UMG_FadingBox_C")
    if boxes then
        for _, b in ipairs(boxes) do
            local ok, p = pcall(function() return b:GetFullName() end)
            if ok and p:find("DrivingGameEngine") and p:find("UMG_Feedback_ItemStream") then
                streamBox = b
                break
            end
        end
    end
    if not streamBox then return false end

    -- Find live stream widget
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    if all then
        for _, obj in ipairs(all) do
            local ok, p = pcall(function() return obj:GetFullName() end)
            if ok and p:find("DrivingGameEngine") then
                streamWidget = obj
                break
            end
        end
    end
    if not streamWidget then return false end

    -- Resize slot
    local slot = streamWidget.Slot
    if slot then
        local slotPath = slot:GetFullName():match("^%S+%s+(.+)$")
        PDSetSlotSize(slotPath, 10000, 800)
    end

    -- Increase max elements
    streamBox.MaxElements = 25

    streamInitialized = true
    return true
end

-- Creates a single stream entry and returns its live handles so callers can
-- mutate or expire it later. Returns (entry, widget, entryPath) on success, or
-- nil on failure (caller decides whether to fall back to an alert).
--
-- This is the shared core of both uim.sendStreamMessage (fire-and-forget) and
-- the OOP Message layer. `widget` is the UMG_FadingBox_Widget_C wrapper that
-- owns SetLifetime; it may be nil even on success (entry without a findable
-- wrapper), in which case lifetime control is unavailable but text still shows.
local function createStreamEntry(message, duration)
    if not InitStream() then return nil end

    -- Snapshot before
    local beforeEntries = {}
    local beforeWidgets = {}
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok then beforeEntries[fn] = true end
    end
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok then beforeWidgets[fn] = true end
    end

    -- Create entry
    streamWidget:OnPickedUp(nil)

    -- Find new entry
    local newEntry = nil
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok and not beforeEntries[fn] then newEntry = e break end
    end

    -- Find new wrapper widget
    local newWidget = nil
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok and not beforeWidgets[fn] then newWidget = w break end
    end

    if not newEntry then
        print(LOG_PREPEND .. "[Stream] Failed to find new entry")
        return nil
    end

    -- Set text
    local entryPath = newEntry:GetFullName():match("^%S+%s+(.+)$")
    PDSetFText(entryPath, "Text", message)
    newEntry:UpdateInfo()

    -- Set lifetime
    if newWidget then
        pcall(function() newWidget:SetLifetime(duration) end)
    end

    return newEntry, newWidget, entryPath
end

function uim.sendStreamMessage(message, duration)
    duration = duration or 6.0

    local entry = createStreamEntry(message, duration)
    if not entry then
        -- fallback to top-center alert
        local fm = FindFirstOf("BP_FeedbackManager_C")
        if fm then
            local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
            PDShowInventoryMessage(message, fmPath)
        end
        return false
    end

    return true
end


function uim.sendMessage(msg_source, message, messageType, preferredDuration, forceSplitNewlines)

    local duration = preferredDuration or 8.0
    local forceSplit = forceSplitNewlines == true

    local messageLines = {}
    for line in string.gmatch(message, "[^\n]+") do
        table.insert(messageLines, line)
    end
    local logsSafeMessage = table.concat(messageLines, "\n")

    if messageType == uim.MessageTypes.ALERT then
        local fm = FindFirstOf("BP_FeedbackManager_C")
        if fm then
            local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
            PDShowInventoryMessage(message, fmPath)
        end
        print(LOG_PREPEND .. "[" .. msg_source .. "] Alert: " .. logsSafeMessage)

    elseif messageType == uim.MessageTypes.CHATLIKE then
        if forceSplit then
            for i = #messageLines, 1, -1 do
                uim.sendStreamMessage(messageLines[i], duration)
            end
        else
            uim.sendStreamMessage(message, duration)
        end
        print(LOG_PREPEND .. "[" .. msg_source .. "] Chatlike: " .. logsSafeMessage)

    elseif messageType == uim.MessageTypes.LOGS then
        print(LOG_PREPEND .. "[" .. msg_source .. "] " .. logsSafeMessage)
        if show_info_logs then
            uim.sendStreamMessage("[LOG] " .. message, duration)
        end

    elseif messageType == uim.MessageTypes.ERR then
        print(LOG_PREPEND .. "[" .. msg_source .. "] [ERROR] " .. logsSafeMessage)
        if show_err_logs then
            local fm = FindFirstOf("BP_FeedbackManager_C")
            if fm then
                local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
                PDShowInventoryMessage("[ERR] " .. message, fmPath)
            end
        end
    end
end


-- ============================================================
-- Messenger / Message  (OOP layer, built on top of the above)
-- ============================================================
--
-- This is an additive layer; uim.sendMessage / uim.sendStreamMessage keep
-- working unchanged. Create one Messenger per module instead of passing the
-- source name on every call:
--
--   local msg = uim.newMessenger("DLCGarage")
--   msg:logInfo("loaded")                      -- LOGS,  returns nil
--   msg:logErr("something broke: " .. err)     -- ERR,   returns nil
--   msg:alert("Done!")                         -- ALERT only, returns nil
--   local m = msg:alert("Saved", "Bookmark saved")  -- alert + feedback toast
--   local m = msg:feedback("Working...")       -- feedback toast, returns Message|nil
--
-- alert(alertStr, [feedbackStr], [duration], [split]):
--   Always shows the top-center banner. If feedbackStr is non-nil it ALSO
--   fires a feedback toast and returns that Message (your common alert+feedback
--   case). feedbackStr == nil -> banner only, returns nil.
--
-- feedback(message, [duration], [split]) and the feedback half of alert return
-- a Message handle (or nil if the stream couldn't create an entry). logInfo /
-- logErr / banner-only alert return nil — those vanish on their own, there's
-- nothing to hold onto.
--
-- `split`, when given, is a DELIMITER STRING (e.g. "\n", "<split>"): the text
-- is split on it and each piece becomes its own stacked toast, all owned by the
-- single returned Message. nil/false = one toast.

-- Split `text` on the literal delimiter `delim` (preserving empty segments).
-- nil/empty delim -> a single-element list. Used by both creation and setText
-- so a message's line count stays stable across updates.
local function splitLines(text, delim)
    if not delim or delim == "" then return { text } end
    local lines = {}
    local start = 1
    while true do
        local s, e = string.find(text, delim, start, true)
        if not s then table.insert(lines, text:sub(start)); break end
        table.insert(lines, text:sub(start, s - 1))
        start = e + 1
    end
    return lines
end

-- Wrap `text` so no line exceeds `width` characters (default 180). The game
-- uses mono fonts, so char count == visual width. OPT-IN: call this yourself
-- and pass the result on (e.g. msg:feedback(uim.wrapText(s), "\n")). It is
-- never applied automatically, so manual spacing/\t alignment tricks are left
-- alone unless you explicitly run them through here.
--
-- Existing "\n" breaks are preserved (each line is wrapped independently).
-- Wrapping prefers to break at spaces; a single word longer than `width` is
-- hard-split. Returns a "\n"-joined string.
function uim.wrapText(text, width)
    width = width or 180
    if width < 1 then width = 1 end

    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if #line <= width then
            table.insert(out, line)
        else
            -- Greedily pack whitespace-separated words; hard-split overlong words.
            local cur = ""
            for word in line:gmatch("%S+") do
                while #word > width do
                    -- Word alone overflows: flush current line, emit a full slice.
                    if cur ~= "" then table.insert(out, cur); cur = "" end
                    table.insert(out, word:sub(1, width))
                    word = word:sub(width + 1)
                end
                if cur == "" then
                    cur = word
                elseif #cur + 1 + #word <= width then
                    cur = cur .. " " .. word
                else
                    table.insert(out, cur)
                    cur = word
                end
            end
            table.insert(out, cur)
        end
    end
    return table.concat(out, "\n")
end

uim.TIME = {
    CONFIRM = "confirm",
    REGULAR = "regular",
    HELP    = "help",
    PROBLEM = "problem"
}

local KEYWORD_TO_TIME_MULT = {
    ["confirm"] = 0.7,
    ["regular"] = 1.0,
    ["help"]    = 1.3,
    ["problem"] = 2.0
}

-- Estimates reading time
local TIME_PER_CHAR = 0.03
function uim.readTime(text, mult)
    if mult == nil then mult = 1 end
    if type(mult) == "string" then
        mult = KEYWORD_TO_TIME_MULT[mult] or 1
    end
    return 4 + #text * TIME_PER_CHAR * mult
end

-- Resolve a `duration` argument into a concrete number of seconds, so callers
-- don't have to guess a length or call readTime() themselves. Accepts:
--   nil      -> auto: readTime(text) at the regular pace (length-based)
--   number   -> explicit seconds, used as-is
--   string   -> a uim.TIME preset name (e.g. "confirm"/"help"); the preset's
--               multiplier is applied to readTime(text). Unknown name -> mult 1.
-- (Numbers and strings never collide, so the two modes are unambiguous. Want a
-- raw multiplier that isn't a preset? add it to uim.TIME, or pass an explicit
-- number / your own uim.readTime(text, mult).)
local function resolveDuration(text, duration)
    if duration == nil then
        return uim.readTime(text)
    elseif type(duration) == "number" then
        return duration
    elseif type(duration) == "string" then
        return uim.readTime(text, KEYWORD_TO_TIME_MULT[duration] or 1)
    end
    return uim.readTime(text)
end

-- ---- Message ------------------------------------------------

local Message = {}
Message.__index = Message

-- entries: array (top-to-bottom display order) of { entry, widget, path }
-- text:    the current full message string (used to re-resolve length-based
--          durations when the text changes via setText).
-- durationSpec: the original duration argument (nil | number | preset string);
--          kept so setText/setDuration can re-resolve against new text.
local function newMessage(entries, text, durationSpec)
    local self = setmetatable({
        _entries      = entries,
        _text         = text,
        _durationSpec = durationSpec,
        _duration     = resolveDuration(text, durationSpec),
        _expired      = false,
        _gen          = 0,    -- bumped on (re)schedule so stale timers no-op
    }, Message)
    activeMessages[self] = true
    self:_scheduleExpiry()
    return self
end

-- Schedule the bookkeeping unregister. The game fades the widget visually via
-- SetLifetime; this timer only governs when we drop the handle from the
-- registry. Bumping _gen invalidates any previously scheduled timer.
function Message:_scheduleExpiry()
    self._gen = self._gen + 1
    local gen = self._gen
    local ms = math.floor((self._duration or DEFAULT_FEEDBACK_DURATION) * 1000) + 250
    ExecuteWithDelay(ms, function()
        if self._expired or self._gen ~= gen then return end
        self._expired = true
        activeMessages[self] = nil
    end)
end

function Message:isExpired()
    return self._expired
end

-- EStretch / EStretchDirection enum values (the dump shows ScaleBox_1 uses
-- ScaleToFitX + DownOnly). Re-applying these via the SetStretch UFUNCTIONs takes
-- only enum args (NO FText crosses Lua, so it can't trigger the FText AV crash),
-- and ScaleBox's setters don't equality-guard, so re-setting the SAME value
-- still forces the ScaleBox to drop its cached scale and re-measure content.
local ESTRETCH_SCALE_TO_FIT_X    = 3
local ESTRETCHDIR_DOWN_ONLY      = 1
local ESLATEVIS_COLLAPSED        = 1   -- ESlateVisibility::Collapsed

-- Internal: re-run the native Slate layout for an entry after its text changed.
-- `rec` = { entry, widget, path } (widget is the UMG_FadingBox_Widget wrapper,
-- which is the DIRECT child of the MessagesBox VerticalBox).
--
-- The entry's text (NameActionText) lives inside ScaleBox_1, which scales the
-- text DOWN to fit a box width measured once at creation. Two stale caches must
-- be busted:
--   1. The ScaleBox's own scale + the entry's desired size  -> ForceLayoutPrepass
--      on text -> scalebox -> row -> entry, plus re-applying SetStretch.
--   2. The parent VerticalBox's slot ARRANGEMENT. A VerticalBox only re-arranges
--      its children when one is added/removed/collapsed — NOT when a child's
--      desired size changes in place. (Observed: the entry only snaps to the
--      right size once a sibling below it vanishes and the box re-flows.) So we
--      reproduce that trigger: briefly collapse the wrapper widget and restore
--      its original visibility, forcing the VerticalBox to re-query child sizes.
--
-- All pcall'd and name-guarded; the visibility toggle is skipped entirely if we
-- can't read the original value, so the widget can never get stuck hidden.
local function refreshEntryLayout(rec)
    local entry = rec.entry
    pcall(function()
        local t  = entry.NameActionText
        local sb = entry.ScaleBox_1

        if t then t:ForceLayoutPrepass() end

        if sb then
            -- Re-drive the ScaleBox: setting stretch re-invalidates its scale.
            pcall(function() sb:SetStretch(ESTRETCH_SCALE_TO_FIT_X) end)
            pcall(function() sb:SetStretchDirection(ESTRETCHDIR_DOWN_ONLY) end)
            sb:ForceLayoutPrepass()
        end

        if entry.ItemStreamBox then entry.ItemStreamBox:ForceLayoutPrepass() end
        entry:ForceLayoutPrepass()
    end)

    -- Force the parent VerticalBox to re-arrange (collapse -> restore wrapper).
    local w = rec.widget
    if w then
        local okVis, vis = pcall(function() return w:GetVisibility() end)
        if okVis and vis ~= nil then
            local collapsedOk = pcall(function() w:SetVisibility(ESLATEVIS_COLLAPSED) end)
            if collapsedOk then
                -- Restore original; if that ever fails, force Visible (0) so the
                -- toast can't be left collapsed/invisible.
                if not pcall(function() w:SetVisibility(vis) end) then
                    pcall(function() w:SetVisibility(0) end)
                end
            end
        end
        pcall(function() w:ForceLayoutPrepass() end)
    end
end

-- Internal: write text to one entry handle in place (no new entry created).
--
-- IMPORTANT: PDSetFText writes the FText via raw memory (dllmain.cpp) and does
-- NOT invalidate the Slate STextBlock's cached desired size — so the ScaleBox
-- (ScaleToFitX/DownOnly) keeps sizing to the OLD string and clips/shrinks
-- longer text. The proper fix is to drive the TextBlock through its real
-- SetText UFUNCTION so Slate re-measures natively.
--
-- WARNING: calling NameActionText:SetText(...) FROM LUA hard-crashes the game
-- (EXCEPTION_ACCESS_VIOLATION in FText::ToFString during push_textproperty —
-- the documented "FText crashes on direct Lua access" dead end). A pcall does
-- NOT catch an access violation, so we must NOT call it from Lua. The SetText
-- path therefore has to go through a C++ bridge helper (see PDSetTextBlockText).
-- Until that helper exists we use the raw write + ForceLayoutPrepass nudge,
-- which keeps things stable even though it can't fully fix the ScaleBox resize.
local function writeEntryText(rec, text)
    if not rec or not rec.path then return end
    pcall(function()
        if PDSetTextBlockText then
            -- C++ bridge: calls UTextBlock::SetText via ProcessEvent (re-lays out).
            PDSetTextBlockText(rec.path, text)
        else
            PDSetFText(rec.path, "Text", text)
        end
        rec.entry:UpdateInfo()
        refreshEntryLayout(rec)
    end)
end

-- Internal: re-derive the per-entry strings for new text, mapping onto the
-- existing entries by index (in place — never creates entries, so the toast
-- keeps its position in the stack). Overflow lines are dropped; missing lines
-- blank the leftover entries.
function Message:_applyText(text)
    local lines = splitLines(text, self._delim)
    for i, rec in ipairs(self._entries) do
        writeEntryText(rec, lines[i] or "")
    end
end

-- Change the displayed text AND reset the lifetime timer. The duration is
-- re-resolved from the message's original spec against the NEW text, so a
-- length-based duration (nil/auto or a preset like "help") auto-adjusts to the
-- new content; an explicit-seconds spec stays fixed. Use for live updates that
-- should keep the toast alive.
function Message:setText(text)
    if self._expired then return self end
    self._text = text
    self:_applyText(text)
    self._duration = resolveDuration(text, self._durationSpec)
    for _, rec in ipairs(self._entries) do
        if rec.widget then
            pcall(function() rec.widget:SetLifetime(self._duration) end)
        end
    end
    self:_scheduleExpiry()
    return self
end

-- Change the displayed text WITHOUT touching the lifetime timer (for
-- animations / progress updates that shouldn't extend the toast's life). The
-- stored text is still updated so a later setDuration() resolves against it.
function Message:setTextSilent(text)
    if self._expired then return self end
    self._text = text
    self:_applyText(text)
    return self
end

-- Change the duration. Accepts the same forms as feedback/alert: a number
-- (explicit seconds), a uim.TIME preset name (length-based multiplier), or nil
-- (auto reading time). Re-drives SetLifetime on the live toast(s) so the visible
-- fade matches (e.g. a more fitting timer when you flip a page), then
-- reschedules the registry timer.
function Message:setDuration(duration)
    if self._expired then return self end
    self._durationSpec = duration
    self._duration = resolveDuration(self._text, duration)
    for _, rec in ipairs(self._entries) do
        if rec.widget then
            pcall(function() rec.widget:SetLifetime(self._duration) end)
        end
    end
    self:_scheduleExpiry()
    return self
end

-- Remove the toast(s) early and unregister.
function Message:expire()
    if self._expired then return self end
    self._expired = true
    activeMessages[self] = nil
    for _, rec in ipairs(self._entries) do
        if rec.widget then
            pcall(function() rec.widget:SetLifetime(0.01) end)
        end
    end
    return self
end

-- ---- Messenger ----------------------------------------------

local Messenger = {}
Messenger.__index = Messenger

-- Internal: create a feedback Message (one or more stacked toasts).
-- `duration` is a spec: number (seconds) | preset name (string) | nil (auto).
local function createFeedback(message, duration, split)
    -- Resolve once against the full message for the initial visual lifetime; the
    -- spec is also handed to the Message so setText can re-resolve on new text.
    local resolved = resolveDuration(message, duration)

    -- Build the list of lines to display, top-to-bottom.
    local lines = splitLines(message, split)

    -- The stream renders in reverse, so create bottom line first; store the
    -- resulting handles back in top-to-bottom order for index-stable setText.
    local entries = {}
    for i = #lines, 1, -1 do
        local entry, widget, path = createStreamEntry(lines[i], resolved)
        if entry then
            entries[i] = { entry = entry, widget = widget, path = path }
        end
    end

    -- Compact (drop any nil holes from failed creations) preserving order.
    local compact = {}
    for i = 1, #lines do
        if entries[i] then table.insert(compact, entries[i]) end
    end
    if #compact == 0 then return nil end

    local msg = newMessage(compact, message, duration)
    msg._delim = split
    return msg
end

function uim.newMessenger(source)
    return setmetatable({ source = source or "?" }, Messenger)
end

-- LOGS: print to UE4SS log (optionally streamed if show_info_logs). Returns nil.
-- `duration` accepts the same forms as feedback (number | preset name | nil).
function Messenger:logInfo(message, duration)
    uim.sendMessage(self.source, message, uim.MessageTypes.LOGS, resolveDuration(message, duration), false)
    return nil
end

-- ERR: log + (if show_err_logs) a top-center banner. Debug-facing. Returns nil.
-- `duration` accepts the same forms as feedback (number | preset name | nil).
function Messenger:logErr(message, duration)
    uim.sendMessage(self.source, message, uim.MessageTypes.ERR, resolveDuration(message, duration), false)
    return nil
end

-- ALERT (+ optional feedback). Returns the feedback Message if feedbackStr was
-- given and a toast was created, else nil.
function Messenger:alert(alertStr, feedbackStr, duration, split)
    local fm = FindFirstOf("BP_FeedbackManager_C")
    if fm then
        local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
        pcall(function() PDShowInventoryMessage(alertStr, fmPath) end)
    end
    print(LOG_PREPEND .. "[" .. self.source .. "] Alert: " .. tostring(alertStr))

    if feedbackStr ~= nil then
        return self:feedback(feedbackStr, duration, split)
    end
    return nil
end

-- CHATLIKE feedback toast. Returns a Message handle, or nil if creation failed.
function Messenger:feedback(message, duration, split)
    print(LOG_PREPEND .. "[" .. self.source .. "] Feedback: " .. tostring(message))
    return createFeedback(message, duration, split)
end

-- Expire every live feedback Message right now (backs the 'clear' command).
-- Returns the number of messages cleared.
function uim.clearActive()
    local count = 0
    for msg, _ in pairs(activeMessages) do
        count = count + 1
        msg:expire()
    end
    activeMessages = {}
    return count
end

uim.Message = Message
uim.Messenger = Messenger


-- =============================================================
-- TESTING
-- =============================================================

-- local savedFont = nil

-- ExecuteWithDelay(5000, function()
--     local ok, err = pcall(function()
--         RegisterHook("/Game/UI/UXFeedback/Elements/UMG_FadingBox.UMG_FadingBox_C:AddHistoryText",
--             function(self, text, font, listEntry)
--                 print("[FontHook] AddHistoryText fired!")
--                 print("[FontHook] text=" .. tostring(text))
--                 print("[FontHook] font=" .. tostring(font))
--             end
--         )
--     end)
--     print("[FontHook] Register ok=" .. tostring(ok) .. " err=" .. tostring(err))
-- end)

-- local cachedEntry = nil

-- ExecuteWithDelay(5000, function()
--     local ok, err = pcall(function()
--         RegisterHook("/Game/UI/UXFeedback/Elements/UMG_FadingBox.UMG_FadingBox_C:AddHistoryWidget",
--             function(self, content, listEntry)
--                 local ok, obj = pcall(function() return content:get() end)
--                 if ok and obj then
--                     local ok2, name = pcall(function() return obj:GetFullName() end)
--                     if ok2 and name:find("UMG_Feedback_ItemStream_Entry_C") then
--                         local classOk = pcall(function() return obj:GetClass() end)
--                         if classOk then
--                             cachedEntry = obj
--                             print("[EntryCache] Captured entry")
--                         end
--                     end
--                 end
--             end
--         )
--     end)
--     print("[EntryCache] Hook ok=" .. tostring(ok))
-- end)

RegisterConsoleCommandHandler("toasttest2", function(FullCommand, Parameters)
    local msg = table.concat(Parameters, " ")
    if msg == "" then msg = "Hello from PDCmdMod!" end

    if not cachedEntry then
        print("[Toast2] No cached entry — pick up an item first")
        return true
    end

    local classOk = pcall(function() return cachedEntry:GetClass() end)
    if not classOk then
        print("[Toast2] Cached entry went stale")
        cachedEntry = nil
        return true
    end

    local box = nil
    local boxes = FindAllOf("UMG_FadingBox_C")
    if boxes then
        for _, b in ipairs(boxes) do
            local ok, p = pcall(function() return b:GetFullName() end)
            if ok and p:find("DrivingGameEngine") and p:find("UMG_Feedback_ItemStream") then
                box = b
                break
            end
        end
    end

    if not box then print("[Toast2] No box") return true end

    local entryPath = cachedEntry:GetFullName():match("^%S+%s+(.+)$")
    PDSetFText(entryPath, "Text", msg)

    local ok, err = pcall(function()
        box:AddHistoryWidget(cachedEntry, {})
    end)
    print("[Toast2] ok=" .. tostring(ok) .. " err=" .. tostring(err))
    return true
end)


RegisterConsoleCommandHandler("toasttest3", function(FullCommand, Parameters)
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    for _, obj in ipairs(all) do
        local ok, path = pcall(function()
            return obj:GetFullName():match("^%S+%s+(.+)$")
        end)
        if ok and path and path:find("DrivingGameEngine") then
            local funcs = PDEnumerateFunctions(path)
            if funcs then
                for _, f in ipairs(funcs) do
                    print("[Toast3] fn: " .. f)
                end
            end
            break
        end
    end
    return true
end)


RegisterConsoleCommandHandler("toasttest4", function(FullCommand, Parameters)
    local msg = table.concat(Parameters, " ")
    if msg == "" then msg = "Hello from PDCmdMod!" end

    local stream = nil
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    if all then
        for _, obj in ipairs(all) do
            local ok, path = pcall(function()
                return obj:GetFullName():match("^%S+%s+(.+)$")
            end)
            if ok and path and path:find("DrivingGameEngine") then
                stream = obj
                break
            end
        end
    end
    if not stream then print("[Toast4] No stream") return true end

    -- Snapshot entries and widgets before
    local beforeEntries = {}
    local beforeWidgets = {}
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok then beforeEntries[fn] = true end
    end
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok then beforeWidgets[fn] = true end
    end

    stream:OnPickedUp(nil)

    -- Find new entry
    local newEntry = nil
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok and not beforeEntries[fn] then newEntry = e break end
    end

    -- Find new wrapper widget
    local newWidget = nil
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok and not beforeWidgets[fn] then newWidget = w break end
    end

    if not newEntry then print("[Toast4] No new entry") return true end

    local entryPath = newEntry:GetFullName():match("^%S+%s+(.+)$")
    PDSetFText(entryPath, "Text", msg)
    newEntry:UpdateInfo()

    if newWidget then
        local ok, err = pcall(function() newWidget:SetLifetime(99.0) end)
        print("[Toast4] SetLifetime ok=" .. tostring(ok) .. " err=" .. tostring(err))
    else
        print("[Toast4] No new widget found")
    end

    print("[Toast4] Done!")
    return true
end)



RegisterConsoleCommandHandler("toasttest5", function(FullCommand, Parameters)
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    if all then
        for _, obj in ipairs(all) do
            local ok, p = pcall(function() return obj:GetFullName() end)
            if ok and p:find("DrivingGameEngine") then
                local slot = obj.Slot
                if slot then
                    local slotPath = slot:GetFullName():match("^%S+%s+(.+)$")
                    print("[Toast5] Slot path: " .. tostring(slotPath))
                    local ok2, err = pcall(function()
                        PDSetSlotSize(slotPath, 10000, 600)
                    end)
                    print("[Toast5] SetSize ok=" .. tostring(ok2) .. " err=" .. tostring(err))
                end
                break
            end
        end
    end
    return true
end)



return uim
