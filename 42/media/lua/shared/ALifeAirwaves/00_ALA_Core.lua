-- A-Life: Airwaves & Contracts - shared core. One global table, ALifeAirwaves.
-- Nothing here touches Project A-Life at load time; everything is installed at
-- OnGameStart / OnServerStarted (server/ALifeAirwaves/ALA_Boot.lua).
-- Global settings live in the host's Sandbox options, page "A-Life: Airwaves"
-- (SandboxVars.ALifeAirwaves); per-player ones in Options > Mods.

ALifeAirwaves = ALifeAirwaves or {}
local A = ALifeAirwaves

A.MOD_ID = "ALifeAirwaves"
A.VERSION = "0.1.0"
A.TAG = "[ALA]"
A.MODULE = "ALifeAirwaves"
A.SCHEMA = 1

-- Defaults = the Sandbox defaults in 42/media/sandbox-options.txt.
A.defaults = {
    enabled = true,
    broadcastIntervalMinutes = 4,
    sosContractIntervalMinutes = 8,
    sosTimeoutMinutes = 15,
    rewardMultiplier = 100,
    supplyDispatchCooldownMinutes = 12,
    intelCooldownMinutes = 5,
    autoMapMarkers = true,
    requirePoweredRadio = true,
    emergencyFreqKhz = 94200,
    tradeFreqKhz = 101600,
    tacticalFreqKhz = 106400,
    debug = false,
}

A.settings = A.settings or {}
for key, value in pairs(A.defaults) do A.settings[key] = value end

A.metrics = {
    broadcasts = 0, sosCreated = 0, sosAccepted = 0, sosCompleted = 0, sosFailed = 0,
    dispatches = 0, dispatchClaimed = 0, caravanCalls = 0, intelReports = 0,
    mapMarks = 0, radioTunes = 0, radioAired = 0, lines = 0, errors = 0,
}

function A.now()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return math.floor(os.time() * 1000)
end

function A.log(...)
    local parts = { A.TAG }
    for index = 1, select("#", ...) do parts[#parts + 1] = tostring(select(index, ...)) end
    print(table.concat(parts, " "))
end

function A.debug(...)
    if A.settings.debug then A.log(...) end
end

function A.fail(where, err)
    A.metrics.errors = A.metrics.errors + 1
    A.log(where, "failed:", err)
end

function A.rand(n)
    n = math.max(1, math.floor(tonumber(n) or 1))
    if type(ZombRand) == "function" then return ZombRand(n) end
    return math.random(0, n - 1)
end

function A.randFloat()
    if type(ZombRandFloat) == "function" then return ZombRandFloat(0, 1) end
    return A.rand(1000000) / 1000000
end

function A.pick(list)
    if type(list) ~= "table" or #list == 0 then return nil end
    return list[A.rand(#list) + 1]
end

function A.hash(text)
    local value = 5381
    for index = 1, #tostring(text) do value = (value * 33 + string.byte(text, index)) % 4294967296 end
    return value
end

function A.side()
    local server = type(isServer) == "function" and isServer() == true
    local client = type(isClient) == "function" and isClient() == true
    if server then return "server" end
    if client then return "client" end
    return "singleplayer"
end

function A.authority()
    return A.side() ~= "client"
end

local function readXYZ(body)
    return body:getX(), body:getY(), body:getZ()
end

function A.xyz(body)
    if body == nil or type(body.getX) ~= "function" then return nil end
    local ok, x, y, z = pcall(readXYZ, body)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, type(z) == "number" and z or 0
end

function A.dist(x1, y1, x2, y2)
    local dx, dy = (x1 or 0) - (x2 or 0), (y1 or 0) - (y2 or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function A.isEmpty(value)
    if type(value) ~= "table" then return true end
    for _ in pairs(value) do return false end
    return true
end

function A.copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = A.copy(item) end
    return out
end

function A.clamp(value, low, high, default)
    value = tonumber(value)
    if value == nil or value ~= value then return default end
    return math.max(low, math.min(high, value))
end

function A.freqMhz(khz)
    local val = tonumber(khz) or 94200
    return string.format("%.1f MHz", val / 1000)
end

function A.channelFreq(channelKey)
    local s = A.settings
    if channelKey == "trade" then return s.tradeFreqKhz or 101600 end
    if channelKey == "tactical" then return s.tacticalFreqKhz or 106400 end
    return s.emergencyFreqKhz or 94200
end

function A.refreshSettings()
    local sandbox = type(SandboxVars) == "table" and SandboxVars.ALifeAirwaves or nil
    local s = A.settings
    local d = A.defaults
    if type(sandbox) ~= "table" then
        for key, value in pairs(d) do s[key] = value end
        return false
    end
    s.enabled = sandbox.Enabled ~= false
    s.broadcastIntervalMinutes = A.clamp(sandbox.BroadcastIntervalMinutes, 1, 60, d.broadcastIntervalMinutes)
    s.sosContractIntervalMinutes = A.clamp(sandbox.SOSContractIntervalMinutes, 2, 120, d.sosContractIntervalMinutes)
    s.sosTimeoutMinutes = A.clamp(sandbox.SOSTimeoutMinutes, 3, 60, d.sosTimeoutMinutes)
    s.rewardMultiplier = A.clamp(sandbox.RewardMultiplier, 50, 300, d.rewardMultiplier)
    s.supplyDispatchCooldownMinutes = A.clamp(sandbox.SupplyDispatchCooldownMinutes, 1, 120, d.supplyDispatchCooldownMinutes)
    s.intelCooldownMinutes = A.clamp(sandbox.IntelCooldownMinutes, 1, 60, d.intelCooldownMinutes)
    s.autoMapMarkers = sandbox.AutoMapMarkers ~= false
    s.requirePoweredRadio = sandbox.RequirePoweredRadio ~= false
    s.emergencyFreqKhz = A.clamp(sandbox.EmergencyFreqKhz, 88000, 108000, d.emergencyFreqKhz)
    s.tradeFreqKhz = A.clamp(sandbox.TradeFreqKhz, 88000, 108000, d.tradeFreqKhz)
    s.tacticalFreqKhz = A.clamp(sandbox.TacticalFreqKhz, 88000, 108000, d.tacticalFreqKhz)
    s.debug = sandbox.Debug == true
    return true
end

function A.players()
    local out = {}
    local ok = pcall(function()
        if type(getOnlinePlayers) == "function" and (A.side() ~= "singleplayer") then
            local list = getOnlinePlayers()
            for index = 0, list:size() - 1 do out[#out + 1] = list:get(index) end
        end
    end)
    if (not ok or #out == 0) and type(getSpecificPlayer) == "function" then
        for index = 0, 3 do
            local ok2, player = pcall(getSpecificPlayer, index)
            if ok2 and player ~= nil then out[#out + 1] = player end
        end
    end
    if #out == 0 and type(getPlayer) == "function" then
        local ok3, player = pcall(getPlayer)
        if ok3 and player ~= nil then out[#out + 1] = player end
    end
    return out
end

function A.playerKey(player)
    local speech = ProjectALife and ProjectALife.Speech
    if speech ~= nil and type(speech.playerKey) == "function" then
        local ok, key = pcall(speech.playerKey, player)
        if ok and key ~= nil then return tostring(key) end
    end
    local ok, name = pcall(function() return player:getUsername() end)
    if ok and name ~= nil then return tostring(name) end
    return "sp:0"
end

function A.counters()
    local m = A.metrics
    return "broadcasts=" .. m.broadcasts .. " sosCreated=" .. m.sosCreated .. " sosAccepted=" .. m.sosAccepted
        .. " sosCompleted=" .. m.sosCompleted .. " sosFailed=" .. m.sosFailed .. " dispatches=" .. m.dispatches
        .. " dispatchClaimed=" .. m.dispatchClaimed .. " caravanCalls=" .. m.caravanCalls
        .. " intelReports=" .. m.intelReports .. " mapMarks=" .. m.mapMarks .. " radioTunes=" .. m.radioTunes
        .. " radioAired=" .. m.radioAired .. " lines=" .. m.lines .. " errors=" .. m.errors
end

function A.status()
    A.log("v" .. A.VERSION, "side=" .. A.side(), "enabled=" .. tostring(A.settings.enabled))
    A.log(A.counters())
    if A.Director ~= nil and type(A.Director.describe) == "function" then
        for _, line in ipairs(A.Director.describe()) do A.log(line) end
    end
end

return A
