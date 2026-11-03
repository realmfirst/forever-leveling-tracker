-- Realm First Leveling Tracker: XP per hour, time to level, rested XP, time played
-- this level and a session summary in one small movable frame.
-- https://realmfirst.net/world-of-warcraft-forever/
local ADDON, ns = ...
local Calc = ns.Calc

local WINDOW = 15 * 60       -- seconds used for the "recent" XP/h rate
local MIN_SPAN = 60          -- seconds of data before a rate is shown
local REFRESH = 1            -- seconds between frame updates
local LINES = 6

local db
local frame, lines
local session = { start = 0, gained = 0, levels = 0, startLevel = 1, samples = {} }
local last = { xp = 0, max = 0, level = 1 }
local played = { level = nil, at = nil }
local suppressPlayed = false
local elapsedSinceRefresh = 0

local function say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fb3ffRealm First|r: " .. msg)
end

local function maxLevel()
    return (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
end

local function resetSession()
    session.start = GetTime()
    session.gained = 0
    session.levels = 0
    session.startLevel = UnitLevel("player")
    session.samples = {}
end

local function snapshot()
    last.xp = UnitXP("player")
    last.max = UnitXPMax("player")
    last.level = UnitLevel("player")
end

-- Rates: the trailing window when there is enough data, the whole session otherwise.
local function rates()
    local now = GetTime()
    local elapsed = now - session.start
    local recent = Calc.xpPerHour(Calc.windowGain(session.samples, now, WINDOW), math.min(WINDOW, elapsed), MIN_SPAN)
    local overall = Calc.xpPerHour(session.gained, elapsed, MIN_SPAN)
    return recent, overall, elapsed
end

local function playedThisLevel()
    if not played.level then return nil end
    return played.level + (GetTime() - played.at)
end

local function requestPlayed(quiet)
    if not RequestTimePlayed then return end
    suppressPlayed = quiet and true or false
    if suppressPlayed and C_Timer and C_Timer.After then
        C_Timer.After(5, function() suppressPlayed = false end)
    end
    RequestTimePlayed()
end

local function refresh()
    if not frame or not frame:IsShown() then return end
    local level = UnitLevel("player")
    local xp, xpMax = UnitXP("player"), UnitXPMax("player")
    local recent, overall, elapsed = rates()
    local dash = "-"

    if xpMax > 0 and level < maxLevel() then
        lines[1]:SetText(string.format("Level %d: %s / %s XP (%.1f%%)", level,
            Calc.formatNumber(xp), Calc.formatNumber(xpMax), xp / xpMax * 100))
        local perHour = recent or overall
        local eta = Calc.secondsToLevel(xpMax - xp, perHour)
        lines[3]:SetText("Time to level: " .. (Calc.formatDuration(eta) or dash))
        local rested = Calc.restedPercent(GetXPExhaustion(), xpMax)
        lines[4]:SetText(rested > 0 and string.format("Rested: %.0f%% of the bar", rested) or "Rested: none")
    else
        lines[1]:SetText(string.format("Level %d: max level", level))
        lines[3]:SetText("Time to level: " .. dash)
        lines[4]:SetText("Rested: " .. dash)
    end

    lines[2]:SetText(string.format("XP/h: %s (15 min), %s (session)",
        recent and Calc.formatNumber(recent) or dash, overall and Calc.formatNumber(overall) or dash))
    lines[5]:SetText("Time on this level: " .. (Calc.formatDuration(playedThisLevel()) or "waiting for /played"))
    lines[6]:SetText(string.format("Session: %s, +%s XP, %d level%s",
        Calc.formatDuration(elapsed) or dash, Calc.formatNumber(session.gained),
        session.levels, session.levels == 1 and "" or "s"))
end

local function sessionSummary()
    local _, overall, elapsed = rates()
    return string.format("session %s, +%s XP, %d level%s (%d to %d), %s XP/h",
        Calc.formatDuration(elapsed) or "0s", Calc.formatNumber(session.gained),
        session.levels, session.levels == 1 and "" or "s", session.startLevel, UnitLevel("player"),
        overall and Calc.formatNumber(overall) or "-")
end

local function savePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

local function createFrame()
    frame = CreateFrame("Frame", "RealmFirstLevelingFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(270, 28 + LINES * 14)
    frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.75)
    end
    frame:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    frame:SetScript("OnUpdate", function(_, dt)
        elapsedSinceRefresh = elapsedSinceRefresh + dt
        if elapsedSinceRefresh >= REFRESH then
            elapsedSinceRefresh = 0
            refresh()
        end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetText("Realm First Leveling")

    lines = {}
    for i = 1, LINES do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 8, -10 - i * 14)
        fs:SetJustifyH("LEFT")
        lines[i] = fs
    end
    frame:SetShown(db.shown)
end

local function onXPUpdate(unit)
    if unit and unit ~= "player" then return end
    local xp = UnitXP("player")
    local level = Calc.effectiveLevel(last.xp, last.level, xp, UnitLevel("player"))
    local gain = Calc.xpGain(last.xp, last.max, last.level, xp, level)
    if gain > 0 then
        session.gained = session.gained + gain
        session.samples[#session.samples + 1] = { t = GetTime(), gain = gain }
    end
    if level > last.level then
        session.levels = session.levels + (level - last.level)
        played.level, played.at = 0, GetTime()
        requestPlayed(true)
    end
    snapshot()
    last.level = level
    refresh()
end

local function saveLastSession()
    local elapsed = GetTime() - session.start
    if session.gained == 0 and elapsed < 60 then return end
    db.last = {
        name = UnitName("player"),
        date = date("%Y-%m-%d %H:%M"),
        seconds = math.floor(elapsed),
        gained = session.gained,
        levels = session.levels,
        startLevel = session.startLevel,
        endLevel = UnitLevel("player"),
    }
end

local function printLast()
    local l = db.last
    if not l then say("no earlier session saved yet.") return end
    say(string.format("last session (%s, %s): %s, +%s XP, level %d to %d",
        l.name or "?", l.date or "?", Calc.formatDuration(l.seconds) or "0s",
        Calc.formatNumber(l.gained), l.startLevel, l.endLevel))
end

local function setShown(shown)
    db.shown = shown
    frame:SetShown(shown)
    if shown then refresh() end
end

local function help()
    say("commands: /rfl (show or hide), summary, played, last, reset, lock, unlock, help")
end

SLASH_REALMFIRSTLEVELING1 = "/rfl"
SLASH_REALMFIRSTLEVELING2 = "/rflevel"
SlashCmdList["REALMFIRSTLEVELING"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "" or cmd == "toggle" then
        setShown(not frame:IsShown())
    elseif cmd == "show" then
        setShown(true)
    elseif cmd == "hide" then
        setShown(false)
    elseif cmd == "summary" then
        say(sessionSummary())
    elseif cmd == "played" then
        requestPlayed(false)
    elseif cmd == "last" then
        printLast()
    elseif cmd == "reset" then
        resetSession()
        snapshot()
        refresh()
        say("session reset.")
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        say(db.locked and "frame locked." or "frame unlocked, drag it to move.")
    else
        help()
    end
end

-- /played prints to chat by default; hide it when the addon asked for it.
if type(ChatFrame_DisplayTimePlayed) == "function" then
    local original = ChatFrame_DisplayTimePlayed
    ChatFrame_DisplayTimePlayed = function(...)
        if suppressPlayed then
            suppressPlayed = false
            return
        end
        return original(...)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        RealmFirstLevelingDB = RealmFirstLevelingDB or {}
        db = RealmFirstLevelingDB
        if db.point == nil then
            db.point, db.relPoint, db.x, db.y = "CENTER", "CENTER", 0, 0
        end
        if db.shown == nil then db.shown = true end
        if db.locked == nil then db.locked = false end
        events:UnregisterEvent("ADDON_LOADED")
        events:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        createFrame()
        resetSession()
        snapshot()
        events:RegisterEvent("PLAYER_XP_UPDATE")
        events:RegisterEvent("UPDATE_EXHAUSTION")
        events:RegisterEvent("TIME_PLAYED_MSG")
        events:RegisterEvent("PLAYER_LOGOUT")
        requestPlayed(true)
        refresh()
    elseif event == "PLAYER_XP_UPDATE" then
        onXPUpdate(arg1)
    elseif event == "UPDATE_EXHAUSTION" then
        refresh()
    elseif event == "TIME_PLAYED_MSG" then
        -- arg1: total seconds played, arg2: seconds played at this level
        played.level, played.at = arg2, GetTime()
        refresh()
    elseif event == "PLAYER_LOGOUT" then
        saveLastSession()
    end
end)
