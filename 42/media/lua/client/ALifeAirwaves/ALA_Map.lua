-- A-Life: Airwaves & Contracts - client map markers & WorldMapSymbols annotations.
-- Draws live SOS beacons (red/amber cross) and supply drop points (teal box) on
-- ISWorldMap and ISMiniMapInner, and adds persistent WorldMapSymbols annotations
-- when the player carries a writing tool (pen/pencil).

require "ALifeAirwaves/00_ALA_Core"
require "ALifeAirwaves/01_ALA_Lines"
require "ALifeAirwaves/02_ALA_RadioCheck"

local A = ALifeAirwaves
local M = {
    installed = false,
    options = { worldMapOverlay = true },
    markedIds = {},
    customMarks = {},
}
A.Map = M

local function finite(v)
    v = tonumber(v)
    return v ~= nil and v == v and v > -math.huge and v < math.huge and v or nil
end

function M.addSymbolNote(x, y, label, player)
    x, y = finite(x), finite(y)
    if x == nil or y == nil then return false, "bad_coords" end
    if player ~= nil and not A.RadioCheck.canWriteOnMap(player) then
        return false, "no_pen"
    end
    label = tostring(label or "Signal")
    M.customMarks[#M.customMarks + 1] = { x = x, y = y, label = label, atMs = A.now() }
    while #M.customMarks > 32 do table.remove(M.customMarks, 1) end

    pcall(function()
        local mapInst = ISWorldMap_instance
        local mapAPI = mapInst and mapInst.mapAPI or nil
        if mapAPI ~= nil then
            local symAPI = (type(mapAPI.getSymbolsAPIv2) == "function" and mapAPI:getSymbolsAPIv2())
                or (type(mapAPI.getSymbolsAPI) == "function" and mapAPI:getSymbolsAPI())
                or nil
            if symAPI ~= nil and type(symAPI.addUntranslatedText) == "function" then
                local layerId = type(symAPI.getDefaultTextLayerID) == "function" and symAPI:getDefaultTextLayerID() or "map-note"
                local textSym = symAPI:addUntranslatedText(label, layerId, x, y)
                if textSym ~= nil then
                    if type(textSym.setRGBA) == "function" then textSym:setRGBA(0.15, 0.45, 0.40, 1.0) end
                    if type(textSym.setAnchor) == "function" then textSym:setAnchor(0.5, 0.5) end
                end
            end
        end
        if player ~= nil and type(player.playSoundLocal) == "function" then
            player:playSoundLocal("MapAddNote")
        end
    end)

    A.metrics.mapMarks = A.metrics.mapMarks + 1
    return true, label
end

function M.autoMarkBroadcast(entry, player)
    if not A.settings.autoMapMarkers or type(entry) ~= "table" then return false end
    if entry.id and M.markedIds[entry.id] then return false end
    if not finite(entry.x) or not finite(entry.y) then return false end
    if player == nil or not A.RadioCheck.canWriteOnMap(player) then return false end
    if entry.id then M.markedIds[entry.id] = true end
    local label = string.format("[%s] %s (%s)", tostring(entry.speaker or "Radio"), tostring(entry.factionName or "?"), tostring(entry.town or "?"))
    return M.addSymbolNote(entry.x, entry.y, label, player)
end

function M.centerOn(x, y, playerNum)
    x, y = finite(x), finite(y)
    if x == nil or y == nil then return false end
    local ok = pcall(function()
        if ISWorldMap and type(ISWorldMap.ShowWorldMap) == "function" then
            ISWorldMap.ShowWorldMap(tonumber(playerNum) or 0, x, y, 16.5)
        elseif ISWorldMap_instance and ISWorldMap_instance.mapAPI then
            ISWorldMap_instance.mapAPI:centerOn(x, y)
        end
    end)
    return ok
end

function M.drawBeacon(element, sx, sy, color, size, label)
    local s = size or 5
    element:drawRect(sx - s - 1, sy - 2, s * 2 + 2, 4, 0.95, 0.05, 0.05, 0.05)
    element:drawRect(sx - 2, sy - s - 1, 4, s * 2 + 2, 0.95, 0.05, 0.05, 0.05)
    element:drawRect(sx - s, sy - 1, s * 2, 2, 0.98, color[1], color[2], color[3])
    element:drawRect(sx - 1, sy - s, 2, s * 2, 0.98, color[1], color[2], color[3])
    element:drawRectBorder(sx - s - 2, sy - s - 2, s * 2 + 4, s * 2 + 4, 0.85, color[1], color[2], color[3])
    if label and label ~= "" then
        element:drawText(label, sx + s + 6, sy - 6, 0, 0, 0, 0.85, UIFont.Small)
        element:drawText(label, sx + s + 5, sy - 7, color[1], color[2], color[3], 1.0, UIFont.Small)
    end
end

function M.drawOn(element, api, showLabels, size)
    if element == nil or api == nil or type(api.worldToUIX) ~= "function" or type(api.worldToUIY) ~= "function" then return 0 end
    local cl = A.Client
    if cl == nil then return 0 end
    local drawn = 0
    local width, height = element.width or 0, element.height or 0
    for _, c in ipairs(cl.contracts or {}) do
        if (c.state == "open" or c.state == "accepted") and finite(c.x) and finite(c.y) then
            local sx, sy = api:worldToUIX(c.x, c.y), api:worldToUIY(c.x, c.y)
            if sx >= -20 and sy >= -20 and sx <= width + 20 and sy <= height + 20 then
                sx, sy = math.floor(sx + 0.5), math.floor(sy + 0.5)
                local col = c.state == "accepted" and { 0.96, 0.76, 0.32 } or { 0.95, 0.36, 0.34 }
                local lbl = showLabels and ("SOS: " .. tostring(c.callsign or "?") .. " [" .. tostring(c.kind) .. "]") or nil
                M.drawBeacon(element, sx, sy, col, size or 5, lbl)
                drawn = drawn + 1
            end
        end
    end
    for _, d in ipairs(cl.dispatches or {}) do
        if d.state == "ready" and finite(d.x) and finite(d.y) then
            local sx, sy = api:worldToUIX(d.x, d.y), api:worldToUIY(d.x, d.y)
            if sx >= -20 and sy >= -20 and sx <= width + 20 and sy <= height + 20 then
                sx, sy = math.floor(sx + 0.5), math.floor(sy + 0.5)
                local col = { 0.43, 0.82, 0.72 }
                local lbl = showLabels and ("DROP: " .. tostring(d.callsign or "?")) or nil
                M.drawBeacon(element, sx, sy, col, size or 5, lbl)
                drawn = drawn + 1
            end
        end
    end
    for _, m in ipairs(M.customMarks or {}) do
        if finite(m.x) and finite(m.y) then
            local sx, sy = api:worldToUIX(m.x, m.y), api:worldToUIY(m.x, m.y)
            if sx >= -20 and sy >= -20 and sx <= width + 20 and sy <= height + 20 then
                sx, sy = math.floor(sx + 0.5), math.floor(sy + 0.5)
                local col = { 0.65, 0.85, 0.95 }
                M.drawBeacon(element, sx, sy, col, math.max(3, (size or 5) - 1), showLabels and m.label or nil)
                drawn = drawn + 1
            end
        end
    end
    return drawn
end

function M.install()
    if M.installed then return true end
    pcall(function() require "ISUI/Maps/ISWorldMap" end)
    pcall(function() require "ISUI/Maps/ISMiniMap" end)
    if type(ISWorldMap) == "table" and type(ISWorldMap.render) == "function" then
        local original = ISWorldMap.render
        ISWorldMap.render = function(self, ...)
            local result = original(self, ...)
            if M.options.worldMapOverlay then
                pcall(M.drawOn, self, self.mapAPI, true, 5)
            end
            return result
        end
        M.installed = true
    end
    if type(ISMiniMapInner) == "table" and type(ISMiniMapInner.render) == "function" then
        local originalInner = ISMiniMapInner.render
        ISMiniMapInner.render = function(self, ...)
            local result = originalInner(self, ...)
            if M.options.worldMapOverlay then
                pcall(M.drawOn, self, self.mapAPI, false, 3)
            end
            return result
        end
        M.installed = true
    end
    return M.installed
end

return M
