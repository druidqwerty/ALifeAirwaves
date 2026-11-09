-- A-Life: Airwaves & Contracts - client visual style.
-- Matches ALC_Style / ALC_ContactWindow & Jeem public palette.

require "ALifeAirwaves/01_ALA_Lines"

local A = ALifeAirwaves
local U = { icons = {} }
A.Style = U

local fallback = {
    window     = { 0.075, 0.09, 0.105 },
    windowEdge = { 0.28, 0.34, 0.38 },
    panel      = { 0.105, 0.13, 0.15 },
    panelEdge  = { 0.20, 0.26, 0.29 },
    button     = { 0.13, 0.18, 0.20 },
    buttonEdge = { 0.28, 0.36, 0.38 },
    buttonOver = { 0.20, 0.27, 0.29 },
    primary    = { 0.17, 0.31, 0.30 },
    primaryOver = { 0.23, 0.39, 0.36 },
    text       = { 0.88, 0.91, 0.90 },
    muted      = { 0.60, 0.69, 0.70 },
    name       = { 0.96, 0.94, 0.83 },
    accent     = { 0.43, 0.78, 0.69 },
    selected   = { 0.18, 0.31, 0.30 },
    good       = { 0.56, 0.85, 0.65 },
    warn       = { 0.94, 0.72, 0.40 },
    bad        = { 0.93, 0.46, 0.40 },
    tactical   = { 0.48, 0.74, 0.96 },
}

function U.palette()
    local style = ProjectALifeJimmy and ProjectALifeJimmy.Style
    if style and type(style.refresh) == "function" then pcall(style.refresh) end
    local out = {}
    for k, v in pairs(fallback) do
        out[k] = style and style.colors and style.colors[k] or v
    end
    return out
end

function U.rgba(c, a)
    return { r = c[1], g = c[2], b = c[3], a = a or 1 }
end

function U.text(ui, text, x, y, color, font)
    color = color or fallback.text
    ui:drawText(tostring(text or ""), x, y, color[1], color[2], color[3], 1, font or UIFont.Small)
end

function U.fit(text, width, font)
    text = tostring(text or "")
    if type(getTextManager) ~= "function" then return text end
    local tm = getTextManager()
    font = font or UIFont.Small
    if tm:MeasureStringX(font, text) <= width then return text end
    local chars = {}
    for char in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = char
    end
    while #chars > 0 do
        chars[#chars] = nil
        local short = table.concat(chars) .. "..."
        if tm:MeasureStringX(font, short) <= width then return short end
    end
    return ""
end

function U.panel(ui, x, y, w, h, c)
    c = c or U.palette()
    ui:drawRect(x, y, w, h, 0.98, c.panel[1], c.panel[2], c.panel[3])
    ui:drawRectBorder(x, y, w, h, 1, c.panelEdge[1], c.panelEdge[2], c.panelEdge[3])
end

function U.window(win)
    local c = U.palette()
    win.backgroundColor = U.rgba(c.window, 0.98)
    win.borderColor = U.rgba(c.windowEdge)
end

function U.button(button, primary)
    if button == nil then return end
    local c = U.palette()
    button.backgroundColor = U.rgba(primary and c.primary or c.button)
    button.backgroundColorMouseOver = U.rgba(primary and c.primaryOver or c.buttonOver)
    button.borderColor = U.rgba(primary and c.accent or c.buttonEdge)
    button.textColor = U.rgba(c.text)
end

function U.channelColor(channelKey, c)
    c = c or U.palette()
    if channelKey == "trade" then return c.warn end
    if channelKey == "tactical" then return c.tactical end
    return c.accent
end

function U.icon(fullType)
    if not fullType then return nil end
    if U.icons[fullType] == nil then
        local ok, texture = pcall(function()
            local sm = type(getScriptManager) == "function" and getScriptManager() or nil
            local item = sm and sm:FindItem(fullType) or nil
            return item and item:getNormalTexture()
        end)
        U.icons[fullType] = ok and texture or false
    end
    return U.icons[fullType] or nil
end

return U
