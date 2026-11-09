-- A-Life: Airwaves & Contracts - server / singleplayer bootstrap.
-- Waits for Project A-Life to load, initializes the ledger and ZomboidRadio channels,
-- polls Sandbox settings every 2 seconds, ticks the director, and routes client commands.

require "ALifeAirwaves/00_ALA_Core"
require "ALifeAirwaves/01_ALA_Lines"
require "ALifeAirwaves/02_ALA_RadioCheck"
require "ALifeAirwaves/03_ALA_Catalog"
require "ALifeAirwaves/ALA_Ledger"
require "ALifeAirwaves/ALA_ZomboidRadio"
require "ALifeAirwaves/ALA_Director"
require "ALifeAirwaves/ALA_Ops"

local A = ALifeAirwaves
local B = {
    installed = false,
    tries = 0,
    settingsAtMs = 0,
    minute = 0,
    lastReport = nil,
    retryAtMs = 0,
}
A.Boot = B

function B.install()
    if B.installed then return true end
    if A.OBSOLETE then
        B.installed = true
        A.log("Obsolete: merged into A-Life: Caravans 0.8.0")
        return true
    end
    B.tries = B.tries + 1
    local p = ProjectALife
    if type(p) ~= "table" or (p.ActorRegistry == nil and p.Catalog == nil and p.Speech == nil) then
        if B.tries == 1 then A.log("Project A-Life not loaded yet, waiting") end
        return false
    end
    A.refreshSettings()
    local ok, err = pcall(function()
        if A.authority() then
            A.Ledger.open()
            A.ZomboidRadio.load(nil)
            local store = A.Ledger.open()
            if #store.log == 0 and A.settings.enabled then
                A.Director.emitBroadcast(A.now(), "air_sighting")
            end
        end
    end)
    if not ok then
        A.fail("install", err)
        return false
    end
    B.installed = true
    A.log("v" .. A.VERSION .. " installed (" .. A.side() .. ")" .. (A.settings.enabled and "" or ", disabled in sandbox"))
    return true
end

function B.tick()
    if not B.installed or A.OBSOLETE then return end
    local now = A.now()
    if now >= B.settingsAtMs then
        B.settingsAtMs = now + 2000
        pcall(A.refreshSettings)
    end
    if A.authority() then
        local ok, err = pcall(A.Director.tick)
        if not ok then A.fail("director tick", err) end
    end
end

function B.report()
    if not B.installed or A.OBSOLETE then return end
    B.minute = B.minute + 1
    if B.minute % 5 ~= 0 then return end
    local current = A.counters()
    if current == B.lastReport then return end
    B.lastReport = current
    A.log(current)
    if A.settings.debug and A.authority() then
        for _, line in ipairs(A.Director.describe()) do A.log(line) end
    end
end

function B.onClientCommand(module, command, player, args)
    if module ~= A.MODULE or not B.installed or not A.authority() then return end
    local ok, err = pcall(A.Director.command, player, command, args)
    if not ok then A.fail("command " .. tostring(command), err) end
end

local function add(name, callback)
    local event = type(Events) == "table" and Events[name] or nil
    if event ~= nil and type(event.Add) == "function" then event.Add(callback) end
end

local function remove(name, callback)
    local event = type(Events) == "table" and Events[name] or nil
    if event ~= nil and type(event.Remove) == "function" then pcall(event.Remove, callback) end
end

if not A.bootRegistered then
    A.bootRegistered = true
    add("OnGameStart", function() pcall(B.install) end)
    add("OnServerStarted", function() pcall(B.install) end)
    local retry
    retry = function()
        if not B.installed and B.tries <= 900 and A.now() >= B.retryAtMs then
            B.retryAtMs = A.now() + 1000
            pcall(B.install)
        end
        if B.installed or B.tries > 900 then remove("OnTick", retry) end
    end
    add("OnTick", retry)
    add("OnTick", B.tick)
    add("EveryOneMinute", function() pcall(B.report) end)
    add("OnClientCommand", B.onClientCommand)
end

return B
