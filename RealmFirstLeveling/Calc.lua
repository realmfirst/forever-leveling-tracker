-- Pure helpers for Realm First Leveling Tracker. No WoW API calls in this file,
-- so tests/calc_test.lua can run it under plain Lua 5.1.
local _, ns = ...

local Calc = {}
ns.Calc = Calc

-- 1234567 -> "1,234,567"
function Calc.formatNumber(n)
    n = math.floor((n or 0) + 0.5)
    local sign = n < 0 and "-" or ""
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return sign .. out
end

-- 4980 -> "1h 23m", 252 -> "4m 12s", 40 -> "40s"; nil for unusable input
function Calc.formatDuration(seconds)
    if not seconds or seconds ~= seconds or seconds < 0 or seconds == math.huge then
        return nil
    end
    seconds = math.floor(seconds + 0.5)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

-- The client can fire PLAYER_XP_UPDATE before UnitLevel reports the new level.
-- A bar that wrapped (XP went down) means one level was gained even if the API lags.
function Calc.effectiveLevel(prevXP, prevLevel, xp, apiLevel)
    local level = math.max(apiLevel, prevLevel)
    if xp < prevXP and level == prevLevel then level = prevLevel + 1 end
    return level
end

-- XP gained between two PLAYER_XP_UPDATE readings. When the level went up, the
-- rest of the old bar counts too. prevMax is the old level's bar size.
function Calc.xpGain(prevXP, prevMax, prevLevel, xp, level)
    if level > prevLevel then
        local gain = (prevMax - prevXP) + xp
        -- Skipped levels (quest turn-ins can do this) have unknown bar sizes; count what we know.
        return math.max(gain, 0)
    end
    return math.max(xp - prevXP, 0)
end

-- Rested XP as a percentage of the current level bar (can pass 100).
function Calc.restedPercent(rested, xpMax)
    if not rested or not xpMax or xpMax <= 0 then return 0 end
    return rested / xpMax * 100
end

-- XP per hour from a gain over a span of seconds; nil when the span is too short to mean anything.
function Calc.xpPerHour(gain, seconds, minSeconds)
    if not seconds or seconds < (minSeconds or 30) then return nil end
    return gain / seconds * 3600
end

-- Seconds until the bar is full at the given XP/h; nil if there is no usable rate.
function Calc.secondsToLevel(remaining, perHour)
    if not perHour or perHour <= 0 then return nil end
    return remaining / perHour * 3600
end

-- Sum of gains inside the trailing window. samples = { {t=, gain=}, ... } oldest first.
-- Drops samples older than the window from the table in place.
function Calc.windowGain(samples, now, window)
    while samples[1] and samples[1].t < now - window do
        table.remove(samples, 1)
    end
    local total = 0
    for i = 1, #samples do total = total + samples[i].gain end
    return total
end
