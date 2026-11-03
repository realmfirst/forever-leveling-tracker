-- Run from the repo root: lua5.1 tests/calc_test.lua
local ns = {}
assert(loadfile("RealmFirstLeveling/Calc.lua"))("RealmFirstLeveling", ns)
local C = ns.Calc

local failed = 0
local function eq(actual, expected, label)
    if actual ~= expected then
        failed = failed + 1
        print(string.format("FAIL %s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

eq(C.formatNumber(0), "0", "fmt 0")
eq(C.formatNumber(999), "999", "fmt 999")
eq(C.formatNumber(1000), "1,000", "fmt 1000")
eq(C.formatNumber(123456), "123,456", "fmt 123456")
eq(C.formatNumber(1234567.4), "1,234,567", "fmt 1234567")
eq(C.formatNumber(nil), "0", "fmt nil")

eq(C.formatDuration(40), "40s", "dur 40s")
eq(C.formatDuration(252), "4m 12s", "dur 4m12s")
eq(C.formatDuration(4980), "1h 23m", "dur 1h23m")
eq(C.formatDuration(90000), "1d 1h", "dur 1d1h")
eq(C.formatDuration(nil), nil, "dur nil")
eq(C.formatDuration(-5), nil, "dur negative")
eq(C.formatDuration(math.huge), nil, "dur inf")
eq(C.formatDuration(0 / 0), nil, "dur nan")

-- same level: plain difference
eq(C.xpGain(100, 1000, 10, 250, 10), 150, "gain same level")
-- level up: rest of the old bar plus the new XP
eq(C.xpGain(900, 1000, 10, 50, 11), 150, "gain level up")
eq(C.xpGain(100, 1000, 10, 50, 10), 0, "gain never negative")

-- API still reports the old level, but the bar wrapped
eq(C.effectiveLevel(900, 10, 50, 10), 11, "effective level wrapped")
eq(C.effectiveLevel(900, 10, 50, 11), 11, "effective level api ahead")
eq(C.effectiveLevel(100, 10, 250, 10), 10, "effective level same")
eq(C.effectiveLevel(100, 11, 250, 10), 11, "effective level never goes back")

eq(C.restedPercent(nil, 1000), 0, "rested none")
eq(C.restedPercent(250, 1000), 25, "rested 25%")
eq(C.restedPercent(1500, 1000), 150, "rested 150%")
eq(C.restedPercent(100, 0), 0, "rested zero bar")

eq(C.xpPerHour(100, 10, 60), nil, "rate too short")
eq(C.xpPerHour(1000, 1800), 2000, "rate 2000/h")

eq(C.secondsToLevel(1000, 2000), 1800, "eta 30 min")
eq(C.secondsToLevel(1000, 0), nil, "eta zero rate")
eq(C.secondsToLevel(1000, nil), nil, "eta nil rate")

local samples = { { t = 0, gain = 10 }, { t = 100, gain = 20 }, { t = 950, gain = 30 } }
eq(C.windowGain(samples, 1000, 900), 50, "window drops old")
eq(#samples, 2, "window mutates list")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("calc_test: all checks passed")
