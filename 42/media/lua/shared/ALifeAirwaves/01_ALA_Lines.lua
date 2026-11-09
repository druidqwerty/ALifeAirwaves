-- A-Life: Airwaves & Contracts - radio broadcasts, SOS calls, dispatch & UI lines.
-- Texts live in shared/Translate/<lang>/IG_UI.json as IGUI_ALA_<situation>_<n>
-- and IGUI_ALA_ui_<id>.

require "ALifeAirwaves/00_ALA_Core"

local A = ALifeAirwaves
local L = { lastAtMs = {} }
A.Lines = L

L.catalog = {
    air_sighting = { count = 4 },
    air_horde = { count = 3 },
    air_skirmish = { count = 3 },
    air_camp = { count = 3 },
    air_caravan = { count = 3 },
    sos_horde = { count = 3 },
    sos_medical = { count = 3 },
    sos_ammo = { count = 3 },
    sos_breakdown = { count = 3 },
    sos_resolved = { count = 3 },
    dispatch_ack = { count = 2 },
    dispatch_arrived = { count = 2 },
    intel_report = { count = 3 },
}

function L.keys()
    local keys = {}
    for situation, entry in pairs(L.catalog) do
        for index = 1, entry.count do
            keys[#keys + 1] = "IGUI_ALA_" .. situation .. "_" .. index
        end
    end
    table.sort(keys)
    return keys
end

function L.render(text, vars)
    if type(text) ~= "string" then return nil end
    if type(vars) ~= "table" then return text end
    return (string.gsub(text, "{(%w+)}", function(name)
        local value = vars[name]
        if value == nil then return "{" .. name .. "}" end
        return tostring(value)
    end))
end

function L.text(situation, vars, seed)
    local entry = L.catalog[situation]
    if entry == nil then return nil end
    local index
    if type(seed) == "number" then
        index = (math.floor(math.abs(seed)) % entry.count) + 1
    else
        index = A.rand(entry.count) + 1
    end
    local key = "IGUI_ALA_" .. situation .. "_" .. index
    local text = type(getText) == "function" and getText(key) or nil
    if type(text) ~= "string" or text == "" or text == key then return nil end
    return L.render(text, vars), key, index
end

function L.ui(id, fallback, vars)
    local key = "IGUI_ALA_ui_" .. id
    local text = type(getText) == "function" and getText(key) or nil
    if type(text) ~= "string" or text == "" or text == key then text = fallback end
    return L.render(text, vars)
end

function L.say(shell, situation, options)
    options = type(options) == "table" and options or {}
    if shell == nil then return false end
    local now = A.now()
    local key = tostring(options.uid or tostring(shell)) .. ":" .. tostring(situation)
    if now < (L.lastAtMs[key] or 0) then return false end
    local text = L.text(situation, options.vars)
    if text == nil then return false end
    local speech = ProjectALife and ProjectALife.Speech
    if speech == nil or type(speech.say) ~= "function" then return false end
    local ok, shown = pcall(speech.say, shell, text, { gesture = false, earshot = options.earshot or 40 })
    if not ok then
        A.fail("say", shown)
        return false
    end
    if shown == false and type(speech.display) == "function" then
        local uid, factionId
        if type(speech.variable) == "function" then
            local okUid, val = pcall(speech.variable, shell, "ALifeUID")
            if okUid then uid = val end
            local okFac, fac = pcall(speech.variable, shell, "ALifeFactionId")
            if okFac then factionId = fac end
        end
        local color = { 0.85, 0.90, 0.85 }
        local okShow, result = pcall(speech.display, shell, text, color, "directed", uid)
        shown = okShow and result ~= false
    end
    if shown == false then return false end
    L.lastAtMs[key] = now + (tonumber(options.cooldownMs) or 3500)
    A.metrics.lines = A.metrics.lines + 1
    return true, text
end

return L
