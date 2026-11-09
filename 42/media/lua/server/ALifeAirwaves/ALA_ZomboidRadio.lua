-- A-Life: Airwaves & Contracts - integration with vanilla ZomboidRadio / DynamicRadio.
-- Registers 3 dedicated frequencies (Emergency 94.2 MHz, Trade 101.6 MHz, Tactical 106.4 MHz)
-- and broadcasts real RadioBroadCast + RadioLine messages so players hear them on
-- WalkieTalkies, HamRadios, and VehicleRadios tuned to those frequencies.

pcall(function() require "radio/ISDynamicRadio" end)
require "ALifeAirwaves/00_ALA_Core"

local A = ALifeAirwaves
local ZR = {
    channels = {},
    specs = {
        emergency = { uuid = "ALA-EMRG-942", name = "Knox Survivor Emergency", cat = "Emergency" },
        trade     = { uuid = "ALA-TRAD-1016", name = "Caravan & Trade Net", cat = "Amateur" },
        tactical  = { uuid = "ALA-TACT-1064", name = "Knox Tactical Recon", cat = "Military" },
    },
    registered = false,
}
A.ZomboidRadio = ZR

local function categoryEnum(catName)
    if type(ChannelCategory) ~= "table" and type(ChannelCategory) ~= "userdata" then return nil end
    if catName == "Emergency" and ChannelCategory.Emergency ~= nil then return ChannelCategory.Emergency end
    if catName == "Amateur" and ChannelCategory.Amateur ~= nil then return ChannelCategory.Amateur end
    if catName == "Military" and ChannelCategory.Military ~= nil then return ChannelCategory.Military end
    return ChannelCategory.Radio
end

function ZR.load(scriptManager)
    if not A.authority() or not A.settings.enabled then return false end
    A.refreshSettings()
    if scriptManager == nil and type(getZomboidRadio) == "function" then
        local ok, zr = pcall(getZomboidRadio)
        if ok and zr ~= nil and type(zr.getScriptManager) == "function" then
            local ok2, sm = pcall(zr.getScriptManager, zr)
            if ok2 then scriptManager = sm end
        end
    end
    if scriptManager == nil then return false end

    for key, spec in pairs(ZR.specs) do
        local freq = A.channelFreq(key)
        local ch = nil
        pcall(function()
            ch = scriptManager:getRadioChannel(spec.uuid)
            if ch == nil and DynamicRadioChannel ~= nil and type(DynamicRadioChannel.new) == "function" then
                local cat = categoryEnum(spec.cat)
                local candidate = DynamicRadioChannel.new(spec.name, freq, cat, spec.uuid)
                scriptManager:AddChannel(candidate, false)
                ch = scriptManager:getRadioChannel(spec.uuid) or candidate
            end
        end)
        if ch ~= nil then
            ZR.channels[key] = ch
            if type(DynamicRadio) == "table" and type(DynamicRadio.cache) == "table" then
                DynamicRadio.cache[spec.uuid] = ch
            end
        end
    end
    return not A.isEmpty(ZR.channels)
end

function ZR.air(channelKey, speaker, text, color)
    if not A.authority() or type(text) ~= "string" or text == "" then return false end
    if A.isEmpty(ZR.channels) then ZR.load(nil) end
    local ch = ZR.channels[channelKey or "emergency"]
    if ch == nil then
        local knox = ProjectALife and (ProjectALife.KnoxRadio or ProjectALife.KnoxCountyRadio)
        ch = knox and knox.channel or nil
    end
    if ch == nil then return false end
    if RadioBroadCast == nil or RadioLine == nil then return false end
    color = type(color) == "table" and color or { 0.85, 0.92, 0.82 }
    local prefix = (type(speaker) == "string" and speaker ~= "") and (speaker .. ": ") or ""
    local ok = pcall(function()
        local bc = RadioBroadCast.new("ala-" .. tostring(channelKey) .. "-" .. tostring(A.now()), -1, -1)
        bc:AddRadioLine(RadioLine.new(prefix .. text, color[1] or 0.85, color[2] or 0.9, color[3] or 0.8))
        ch:setAiringBroadcast(bc)
    end)
    if ok then
        A.metrics.radioAired = A.metrics.radioAired + 1
    end
    return ok
end

if not ZR.registered and type(Events) == "table" then
    ZR.registered = true
    if Events.OnLoadRadioScripts ~= nil and type(Events.OnLoadRadioScripts.Add) == "function" then
        Events.OnLoadRadioScripts.Add(function(sm) pcall(ZR.load, sm) end)
    end
    if Events.OnGameStart ~= nil and type(Events.OnGameStart.Add) == "function" then
        Events.OnGameStart.Add(function() pcall(ZR.load, nil) end)
    end
end

return ZR
