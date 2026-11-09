-- A-Life: Airwaves & Contracts - client entry point.
-- Handles server state & broadcast messages, overhead HaloText notices,
-- inventory & world radio context menus, hotkey toggle, and PZAPI.ModOptions.

require "ALifeAirwaves/00_ALA_Core"
require "ALifeAirwaves/01_ALA_Lines"
require "ALifeAirwaves/02_ALA_RadioCheck"
require "ALifeAirwaves/03_ALA_Catalog"
require "ALifeAirwaves/ALA_Style"
require "ALifeAirwaves/ALA_Map"
require "ALifeAirwaves/ALA_AirwavesWindow"

local A = ALifeAirwaves
local L = A.Lines
local Cl = {
    options = {
        openKey = (type(Keyboard) == "table" and Keyboard.KEY_F9) or 67,
        haloNotices = true,
        contextMenu = true,
        freqFilter = 1,
        worldMapOverlay = true,
    },
    log = {},
    contracts = {},
    dispatches = {},
    intel = {},
    favor = {},
    caravansActive = false,
    requestedAtMs = 0,
    window = nil,
}
A.Client = Cl

local function player0(playerNum)
    if type(getSpecificPlayer) == "function" then
        local ok, p = pcall(getSpecificPlayer, tonumber(playerNum) or 0)
        if ok and p ~= nil then return p end
    end
    return A.players()[1]
end

function Cl.send(command, args, playerNum)
    local player = player0(playerNum)
    if player == nil then return end
    if type(isClient) == "function" and isClient() then
        pcall(sendClientCommand, player, A.MODULE, command, args or {})
    elseif A.Director ~= nil and type(A.Director.command) == "function" then
        local ok, err = pcall(A.Director.command, player, command, args or {})
        if not ok then A.fail("local command " .. tostring(command), err) end
    end
end

function Cl.notice(text, playerNum)
    if not Cl.options.haloNotices or type(text) ~= "string" or text == "" then return end
    local player = player0(playerNum)
    if player == nil then return end
    pcall(function()
        if HaloTextHelper ~= nil and type(HaloTextHelper.addText) == "function" then
            HaloTextHelper.addText(player, text)
        elseif type(player.Say) == "function" then
            player:Say(text)
        end
    end)
end

function Cl.passesFilter(channelKey)
    local idx = tonumber(Cl.options.freqFilter) or 1
    if idx == 2 then return channelKey == "emergency" end
    if idx == 3 then return channelKey == "trade" end
    if idx == 4 then return channelKey == "tactical" end
    return true
end

function Cl.receive(module, command, args)
    if module ~= A.MODULE or type(args) ~= "table" then return end
    local p = player0(args.playerNum)
    if command == "state" then
        Cl.log = type(args.log) == "table" and args.log or Cl.log
        Cl.contracts = type(args.contracts) == "table" and args.contracts or Cl.contracts
        Cl.dispatches = type(args.dispatches) == "table" and args.dispatches or Cl.dispatches
        Cl.intel = type(args.intel) == "table" and args.intel or Cl.intel
        Cl.favor = type(args.favor) == "table" and args.favor or Cl.favor
        Cl.caravansActive = args.caravansActive == true
        if Cl.window ~= nil then Cl.window:refresh() end
    elseif command == "broadcast" then
        local entry = args.entry
        if type(entry) == "table" then
            local canRx = A.RadioCheck.canReceive(p, entry.freq)
            if canRx and Cl.passesFilter(entry.channel) then
                Cl.notice(string.format("[%s] %s", A.freqMhz(entry.freq or 94200), tostring(entry.text or "")), args.playerNum)
                A.Map.autoMarkBroadcast(entry, p)
            end
        end
        if Cl.window ~= nil then Cl.window:refresh() end
    elseif command == "sosCreated" then
        local c = args.contract
        if type(c) == "table" then
            local canRx = A.RadioCheck.canReceive(p, c.freq)
            if canRx and Cl.passesFilter(c.channel) then
                Cl.notice(L.ui("notice_sos_incoming", "SOS [{callsign}] near {town} ({x},{y})", {
                    callsign = c.callsign, town = c.town, x = c.x, y = c.y
                }), args.playerNum)
                A.Map.autoMarkBroadcast(args.broadcast or c, p)
            end
        end
        if Cl.window ~= nil then Cl.window:refresh() end
    elseif command == "sosNotice" then
        local key = tostring(args.key or "")
        if key == "accepted" then
            Cl.notice(L.ui("notice_sos_accepted", "SOS Contract accepted: {callsign} near {town} ({x},{y})", args), args.playerNum)
        elseif key == "completed" then
            Cl.notice(L.ui("notice_sos_completed", "SOS Contract completed! +{favor} Favor with {faction}", args), args.playerNum)
        end
        if Cl.window ~= nil then Cl.window:refresh() end
    elseif command == "dispatchNotice" then
        local key = tostring(args.key or "")
        if key == "dispatched" and type(args.dispatch) == "table" then
            local d = args.dispatch
            Cl.notice(L.ui("notice_dispatch_sent", "Supply drop [{callsign}] ready near {town} ({x},{y})", {
                callsign = d.callsign, town = d.town, x = d.x, y = d.y
            }), args.playerNum)
            A.Map.autoMarkBroadcast(args.broadcast or d, p)
        elseif key == "claimed" then
            Cl.notice(L.ui("notice_dispatch_claimed", "Claimed supply drop from {callsign}!", args), args.playerNum)
        elseif key == "caravan_called" then
            Cl.notice(L.ui("notice_caravan_called", "Caravan {callsign} responded at ({x},{y})", args), args.playerNum)
            if args.broadcast then A.Map.autoMarkBroadcast(args.broadcast, p) end
        end
        if Cl.window ~= nil then Cl.window:refresh() end
    elseif command == "intelNotice" then
        if type(args.report) == "table" then
            local r = args.report
            Cl.notice(L.ui("notice_intel_ready", "Recon [{town}]: {squads} squads, {outposts} outposts, threat {danger}", {
                town = r.townName, squads = r.squads, outposts = r.outposts, danger = string.upper(tostring(r.danger or "low"))
            }), args.playerNum)
        end
        if Cl.window ~= nil then Cl.window:refresh() end
    elseif command == "notice" then
        if type(args.key) == "string" then
            Cl.notice(L.ui(args.key, args.key, args.vars), args.playerNum)
        elseif type(args.text) == "string" then
            Cl.notice(args.text, args.playerNum)
        end
    end
end

function Cl.fillInventoryMenu(playerNum, context, items)
    if not Cl.options.contextMenu or type(context) ~= "table" or type(context.addOption) ~= "function" then return end
    local foundRadio = false
    for _, v in ipairs(items or {}) do
        local item = type(v) == "table" and v.items and v.items[1] or v
        if item ~= nil and ((type(instanceof) == "function" and instanceof(item, "Radio")) or type(item.getDeviceData) == "function") then
            foundRadio = true
            break
        end
    end
    if not foundRadio then return end
    context:addOption(L.ui("menu_open_airwaves", "[A-LIFE] Open Airwaves & Contracts"), nil, function()
        A.Style.openWindow(playerNum, "log")
    end)
end

function Cl.fillWorldMenu(playerNum, context, worldobjects, test)
    if not Cl.options.contextMenu or test == true then return end
    if type(context) ~= "table" or type(context.addOption) ~= "function" then return end
    local p = player0(playerNum)
    if p == nil or (type(p.isDead) == "function" and p:isDead()) then return end
    local px, py = A.xyz(p)
    local scan = A.RadioCheck.scanPlayerRadios(p)
    local nearSOS, nearDrop = nil, nil
    if px ~= nil then
        for _, c in ipairs(Cl.contracts or {}) do
            if (c.state == "open" or c.state == "accepted") and c.x and A.dist(px, py, c.x, c.y) <= 28 then
                nearSOS = c
                break
            end
        end
        for _, d in ipairs(Cl.dispatches or {}) do
            if d.state == "ready" and d.x and A.dist(px, py, d.x, d.y) <= 25 then
                nearDrop = d
                break
            end
        end
    end
    if not scan.hasRadio and nearSOS == nil and nearDrop == nil then return end

    local root = context:addOption(L.ui("menu_root", "[A-LIFE] Airwaves & Contracts"))
    if type(context.getNew) == "function" and type(context.addSubMenu) == "function" then
        local sub = context:getNew(context)
        context:addSubMenu(root, sub)
        sub:addOption(L.ui("menu_open_log", "Open Airwaves Log"), nil, function() A.Style.openWindow(playerNum, "log") end)
        sub:addOption(L.ui("menu_open_sos", "Open SOS & Contracts"), nil, function() A.Style.openWindow(playerNum, "sos") end)
        sub:addOption(L.ui("menu_open_dispatch", "Open Supply & Intel"), nil, function() A.Style.openWindow(playerNum, "dispatch") end)
        if nearSOS ~= nil then
            sub:addOption(L.ui("menu_fulfill_sos", "SOS [{callsign}]: Deliver Aid / Complete", { callsign = nearSOS.callsign }), nil, function()
                Cl.send("fulfillSOS", { id = nearSOS.id }, playerNum)
            end)
        end
        if nearDrop ~= nil then
            sub:addOption(L.ui("menu_claim_drop", "Claim Supply Drop [{callsign}]", { callsign = nearDrop.callsign }), nil, function()
                Cl.send("claimDispatch", { id = nearDrop.id }, playerNum)
            end)
        end
    end
end

function Cl.onKeyPressed(key)
    local bind = tonumber(Cl.options.openKey) or 67
    if key == bind then
        local p = player0(0)
        if p ~= nil and not (type(p.isDead) == "function" and p:isDead()) then
            A.Style.openWindow(0, nil)
        end
    end
end

function Cl.tick()
    local now = A.now()
    if now < Cl.requestedAtMs then return end
    Cl.requestedAtMs = now + 15000
    Cl.send("stateRequest", {}, 0)
end

function Cl.installOptions()
    if type(PZAPI) ~= "table" or PZAPI.ModOptions == nil or Cl.optionsInstalled then return end
    Cl.optionsInstalled = true
    local ok, err = pcall(function()
        local options = PZAPI.ModOptions:create("ALifeAirwaves", "A-Life: Airwaves & Contracts")
        options:addDescription("UI_ALA_Options_Info")
        local defaultKey = (type(Keyboard) == "table" and Keyboard.KEY_F9) or 67
        local openKey = options:addKeyBind("openKey", "UI_ALA_Opt_OpenKey", defaultKey, "UI_ALA_Opt_OpenKey_tt")
        local halo = options:addTickBox("haloNotices", "UI_ALA_Opt_HaloNotices", true, "UI_ALA_Opt_HaloNotices_tt")
        local menu = options:addTickBox("contextMenu", "UI_ALA_Opt_ContextMenu", true, "UI_ALA_Opt_ContextMenu_tt")
        local worldMap = options:addTickBox("worldMapOverlay", "UI_ALA_Opt_WorldMap", true, "UI_ALA_Opt_WorldMap_tt")
        local filter = options:addComboBox("freqFilter", "UI_ALA_Opt_FreqFilter", "UI_ALA_Opt_FreqFilter_tt")
        filter:addItem("UI_ALA_Opt_FreqFilter_1", true)
        filter:addItem("UI_ALA_Opt_FreqFilter_2", false)
        filter:addItem("UI_ALA_Opt_FreqFilter_3", false)
        filter:addItem("UI_ALA_Opt_FreqFilter_4", false)
        options.apply = function()
            Cl.options.openKey = tonumber(openKey:getValue()) or defaultKey
            Cl.options.haloNotices = halo:getValue() ~= false
            Cl.options.contextMenu = menu:getValue() ~= false
            Cl.options.worldMapOverlay = worldMap:getValue() ~= false
            Cl.options.freqFilter = tonumber(filter:getValue()) or 1
            A.Map.options.worldMapOverlay = Cl.options.worldMapOverlay
        end
        options:apply()
    end)
    if not ok then A.fail("mod options", err) end
end

if not A.clientRegistered then
    A.clientRegistered = true
    if A.OBSOLETE then
        A.log("Obsolete: merged into A-Life: Caravans 0.8.0")
    else
        Cl.installOptions()
        A.log("v" .. A.VERSION .. " client loaded")
        if type(Events) == "table" then
            if Events.OnFillInventoryObjectContextMenu then Events.OnFillInventoryObjectContextMenu.Add(Cl.fillInventoryMenu) end
            if Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Cl.fillWorldMenu) end
            if Events.OnServerCommand then Events.OnServerCommand.Add(Cl.receive) end
            if Events.OnKeyPressed then Events.OnKeyPressed.Add(function(k) pcall(Cl.onKeyPressed, k) end) end
            if Events.OnTick then Events.OnTick.Add(function() pcall(Cl.tick) end) end
            if Events.OnGameStart then Events.OnGameStart.Add(function() pcall(A.Map.install) end) end
        end
    end
end

return Cl
