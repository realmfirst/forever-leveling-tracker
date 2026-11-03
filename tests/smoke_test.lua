-- Loads the addon against a mocked WoW API, fires events and runs the slash commands,
-- so runtime errors (nil globals, bad calls) show up without a game client.
-- Run from the repo root: lua5.1 tests/smoke_test.lua
local now = 0
local chat = {}
local player = { xp = 900, max = 1000, level = 10, rested = 250 }
local fontStrings = {}
local scripts = {}
local eventFrames = {}

local function widget()
    local w = { shown = true, texts = {} }
    local mt = {}
    mt.__index = function(t, k)
        if k == "SetShown" then return function(self, v) self.shown = v end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "SetScript" then return function(self, name, fn) scripts[#scripts + 1] = { w = self, name = name, fn = fn } end end
        if k == "RegisterEvent" then return function(self, e) rawset(self, "registered", rawget(self, "registered") or {}); self.registered[e] = true end end
        if k == "UnregisterEvent" then return function(self, e) if rawget(self, "registered") then self.registered[e] = nil end end end
        if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 5, 6 end end
        if k == "CreateFontString" then
            return function()
                local fs = widget()
                fs.SetText = function(self, s) self.text = s end
                fontStrings[#fontStrings + 1] = fs
                return fs
            end
        end
        return function() end
    end
    return setmetatable(w, mt)
end

DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
UIParent = widget()
GetTime = function() return now end
date = os.date
UnitXP = function() return player.xp end
UnitXPMax = function() return player.max end
UnitLevel = function() return player.level end
UnitName = function() return "Tester" end
GetXPExhaustion = function() return player.rested end
GetMaxPlayerLevel = function() return 60 end
RequestTimePlayed = function() end
CreateFrame = function()
    local f = widget()
    eventFrames[#eventFrames + 1] = f
    return f
end
SlashCmdList = {}

local ns = {}
assert(loadfile("RealmFirstLeveling/Calc.lua"))("RealmFirstLeveling", ns)
assert(loadfile("RealmFirstLeveling/RealmFirstLeveling.lua"))("RealmFirstLeveling", ns)

local events = eventFrames[1]
local function fire(event, ...)
    for _, s in ipairs(scripts) do
        if s.w == events and s.name == "OnEvent" then s.fn(events, event, ...) end
    end
end
local function tick(dt)
    now = now + dt
    for _, s in ipairs(scripts) do
        if s.name == "OnUpdate" then s.fn(s.w, dt) end
    end
end
local function text(i) return fontStrings[i + 1].text end -- fontStrings[1] is the title

fire("ADDON_LOADED", "SomeOtherAddon")
assert(RealmFirstLevelingDB == nil, "must ignore other addons")
fire("ADDON_LOADED", "RealmFirstLeveling")
assert(RealmFirstLevelingDB, "db created")
fire("PLAYER_LOGIN")
tick(1)
assert(text(1):find("Level 10"), text(1))
assert(text(4):find("25%%"), text(4))
assert(text(5):find("waiting"), text(5))

-- gain 50 XP, 2 minutes in
tick(120)
player.xp = 950
fire("PLAYER_XP_UPDATE", "player")
tick(1)
assert(text(2):find("XP/h"), text(2))
assert(not text(2):find("%(15 min%), %-"), "session rate present: " .. text(2))
assert(text(3):find("Time to level: %d"), text(3))

-- level up where UnitLevel lags behind the wrapped bar
player.xp = 30
fire("PLAYER_XP_UPDATE", "player")
assert(text(6):find("1 level"), text(6))
player.level = 11
tick(1)
assert(text(1):find("Level 11"), text(1))

-- played message
fire("TIME_PLAYED_MSG", 5000, 600)
tick(1)
assert(text(5):find("10m"), text(5))

-- other units are ignored
local before = text(6)
fire("PLAYER_XP_UPDATE", "pet")
assert(text(6) == before)

-- slash commands
local slash = SlashCmdList["REALMFIRSTLEVELING"]
for _, cmd in ipairs({ "summary", "played", "last", "reset", "lock", "unlock", "hide", "show", "", "nonsense" }) do
    slash(cmd)
end
assert(#chat > 0, "slash commands print")
slash("show")

-- max level shows no ETA and no division by zero
player.level, player.max, player.xp = 60, 0, 0
tick(1)
assert(text(1):find("max level"), text(1))

-- a session shorter than a minute without XP is not worth saving; a longer one is
fire("PLAYER_LOGOUT")
assert(RealmFirstLevelingDB.last == nil, "short empty session not saved")
tick(120)
fire("PLAYER_LOGOUT")
assert(RealmFirstLevelingDB.last and RealmFirstLevelingDB.last.seconds >= 120, "last session saved")

print("smoke_test: all checks passed")
