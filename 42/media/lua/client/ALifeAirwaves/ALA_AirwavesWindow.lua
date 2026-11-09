-- A-Life: Airwaves & Contracts - main UI window (ALA_AirwavesWindow).
-- Built on ISCollapsableWindow in the visual style of ALC_ContactWindow / ALC_TradeWindow.
-- Three tabs:
--   1. Airwaves Log (Эфир / Перехваты)
--   2. SOS & Contracts (SOS и Контракты)
--   3. Dispatch & Intel (Снабжение и Разведка)

require "ALifeAirwaves/00_ALA_Core"
require "ALifeAirwaves/01_ALA_Lines"
require "ALifeAirwaves/02_ALA_RadioCheck"
require "ALifeAirwaves/03_ALA_Catalog"
require "ALifeAirwaves/ALA_Style"
require "ALifeAirwaves/ALA_Map"
pcall(require, "ISUI/ISCollapsableWindow")
pcall(require, "ISUI/ISButton")
pcall(require, "ISUI/ISScrollingListBox")

local A = ALifeAirwaves
local U, L = A.Style, A.Lines

local Win = type(ISCollapsableWindow) == "table" and ISCollapsableWindow:derive("ALA_AirwavesWindow") or nil
ALA_AirwavesWindow = Win

local TABS = {
    { id = "log",      key = "tab_log",      fallback = "Airwaves Log" },
    { id = "sos",      key = "tab_sos",      fallback = "SOS & Contracts" },
    { id = "dispatch", key = "tab_dispatch", fallback = "Supply & Intel" },
}

local function player0(playerNum)
    if type(getSpecificPlayer) == "function" then
        local ok, p = pcall(getSpecificPlayer, tonumber(playerNum) or 0)
        if ok and p ~= nil then return p end
    end
    return A.players()[1]
end

if Win then
    function Win:createChildren()
        ISCollapsableWindow.createChildren(self)
        self.activeTab = self.activeTab or "log"
        self.tabButtons = {}
        local tabW = math.floor((self.width - 24 - 12) / 3)
        for i, t in ipairs(TABS) do
            local bx = 12 + (i - 1) * (tabW + 6)
            local btn = ISButton:new(bx, 102, tabW, 28, L.ui(t.key, t.fallback), self, Win.onSelectTab)
            btn.tabId = t.id
            btn:initialise()
            U.button(btn, t.id == self.activeTab)
            self:addChild(btn)
            self.tabButtons[t.id] = btn
        end

        -- Frequency bar (y = 136)
        self.freqButtons = {}
        local freqs = {
            { id = "emergency", label = "94.2 MHz SOS",   khz = A.channelFreq("emergency") },
            { id = "trade",     label = "101.6 MHz Trade", khz = A.channelFreq("trade") },
            { id = "tactical",  label = "106.4 MHz Recon", khz = A.channelFreq("tactical") },
            { id = "scan",      label = L.ui("btn_scan", "Scan Airwaves"), khz = nil },
        }
        local fw = math.floor((self.width - 24 - 18) / 4)
        for i, f in ipairs(freqs) do
            local bx = 12 + (i - 1) * (fw + 6)
            local btn = ISButton:new(bx, 136, fw, 26, f.label, self, Win.onFreqBar)
            btn.freqId = f.id
            btn.freqKhz = f.khz
            btn:initialise()
            U.button(btn, f.id == "scan")
            self:addChild(btn)
            self.freqButtons[#self.freqButtons + 1] = btn
        end

        local listY = 170
        local listH = self.height - listY - 88
        self.list = ISScrollingListBox:new(12, listY, self.width - 24, listH)
        self.list:initialise()
        self.list:instantiate()
        self.list.itemheight = 56
        self.list.selected = 1
        self.list.backgroundColor = U.rgba(U.palette().panel)
        self.list.doDrawItem = function(box, y, item)
            return Win.drawRow(self, box, y, item)
        end
        self:addChild(self.list)

        -- Bottom action buttons
        local btnY = self.height - 76
        local btnW = math.floor((self.width - 24 - 12) / 3)
        self.btnPrimary = ISButton:new(12, btnY, btnW, 30, "", self, Win.onPrimaryAction)
        self.btnPrimary:initialise()
        U.button(self.btnPrimary, true)
        self:addChild(self.btnPrimary)

        self.btnSecondary = ISButton:new(12 + btnW + 6, btnY, btnW, 30, "", self, Win.onSecondaryAction)
        self.btnSecondary:initialise()
        U.button(self.btnSecondary, false)
        self:addChild(self.btnSecondary)

        self.btnMark = ISButton:new(12 + (btnW + 6) * 2, btnY, btnW, 30, L.ui("btn_mark_map", "Mark on Map"), self, Win.onMarkMap)
        self.btnMark:initialise()
        U.button(self.btnMark, false)
        self:addChild(self.btnMark)

        local bottomY = self.height - 38
        self.btnCenter = ISButton:new(12, bottomY, 160, 26, L.ui("btn_center_map", "Show on Map"), self, Win.onCenterMap)
        self.btnCenter:initialise()
        U.button(self.btnCenter, false)
        self:addChild(self.btnCenter)

        self.closeButton = ISButton:new(self.width - 132, bottomY, 120, 26, L.ui("btn_close", "Close"), self, Win.close)
        self.closeButton:initialise()
        U.button(self.closeButton, false)
        self:addChild(self.closeButton)

        self:refresh()
    end

    function Win:onSelectTab(button)
        if button and button.tabId then
            self.activeTab = button.tabId
            self.list.selected = 1
            self:refresh()
        end
    end

    function Win:onFreqBar(button)
        if not button then return end
        if button.freqId == "scan" then
            A.Client.send("scanAirwaves", {}, self.playerNum)
        elseif button.freqKhz then
            A.Client.send("tuneRadio", { freq = button.freqKhz }, self.playerNum)
        end
    end

    function Win:selectedRow()
        local items = self.list and self.list.items or nil
        if type(items) ~= "table" or #items == 0 then return nil end
        local idx = math.max(1, math.min(#items, tonumber(self.list.selected) or 1))
        return items[idx] and items[idx].item or nil
    end

    function Win:onPrimaryAction()
        local row = self:selectedRow()
        if not row then return end
        if self.activeTab == "log" then
            if row.freq then A.Client.send("tuneRadio", { freq = row.freq }, self.playerNum) end
        elseif self.activeTab == "sos" then
            A.Client.send("acceptSOS", { id = row.id }, self.playerNum)
        elseif self.activeTab == "dispatch" then
            if row.rowKind == "pkg" then
                A.Client.send("requestDispatch", { pkgId = row.id }, self.playerNum)
            elseif row.rowKind == "drop" then
                A.Client.send("claimDispatch", { id = row.id }, self.playerNum)
            elseif row.rowKind == "town" then
                A.Client.send("requestIntel", { townId = row.id }, self.playerNum)
            end
        end
    end

    function Win:onSecondaryAction()
        local row = self:selectedRow()
        if self.activeTab == "log" then
            A.Client.send("scanAirwaves", {}, self.playerNum)
        elseif self.activeTab == "sos" then
            if row and row.id then A.Client.send("fulfillSOS", { id = row.id }, self.playerNum) end
        elseif self.activeTab == "dispatch" then
            A.Client.send("callCaravan", {}, self.playerNum)
        end
    end

    function Win:onMarkMap()
        local row = self:selectedRow()
        if not row or not tonumber(row.x) or not tonumber(row.y) then return end
        local p = player0(self.playerNum)
        local label = row.mapLabel or tostring(row.title or row.callsign or "Signal")
        local ok, why = A.Map.addSymbolNote(row.x, row.y, label, p)
        if ok then
            A.Client.notice(L.ui("notice_marked", "Marked on map: {label} ({x},{y})", { label = label, x = row.x, y = row.y }), self.playerNum)
        elseif why == "no_pen" then
            A.Client.notice(L.ui("err_no_pen", "Need a pen or pencil to mark coordinates on the map."), self.playerNum)
        end
    end

    function Win:onCenterMap()
        local row = self:selectedRow()
        if row and tonumber(row.x) and tonumber(row.y) then
            A.Map.centerOn(row.x, row.y, self.playerNum)
        end
    end

    function Win:refresh()
        if not self.list then return end
        self.list:clear()
        local cl = A.Client
        local filterIdx = cl and cl.options and tonumber(cl.options.freqFilter) or 1
        local filterCh = (filterIdx == 2 and "emergency") or (filterIdx == 3 and "trade") or (filterIdx == 4 and "tactical") or nil

        if self.activeTab == "log" then
            for _, entry in ipairs(cl and cl.log or {}) do
                if filterCh == nil or entry.channel == filterCh then
                    local row = {
                        rowKind = "log",
                        id = entry.id,
                        channel = entry.channel or "emergency",
                        freq = entry.freq or A.channelFreq(entry.channel),
                        title = string.format("[%s] %s · %s", A.freqMhz(entry.freq or 94200), tostring(entry.speaker or "Radio"), tostring(entry.town or "?")),
                        subtitle = tostring(entry.text or ""),
                        meta = string.format("%d, %d", math.floor(entry.x or 0), math.floor(entry.y or 0)),
                        x = entry.x,
                        y = entry.y,
                        mapLabel = string.format("[%s] %s (%s)", tostring(entry.speaker or "Radio"), tostring(entry.factionName or "?"), tostring(entry.town or "?")),
                    }
                    self.list:addItem(row.title, row)
                end
            end
        elseif self.activeTab == "sos" then
            local p = player0(self.playerNum)
            local px, py = A.xyz(p)
            for _, c in ipairs(cl and cl.contracts or {}) do
                local dist = (px and c.x) and math.floor(A.dist(px, py, c.x, c.y)) or 0
                local minsLeft = math.max(0, math.ceil(((tonumber(c.deadlineMs) or 0) - A.now()) / 60000))
                local needTxt = c.needKind and L.ui("need_" .. tostring(c.needKind), "Deliver " .. tostring(c.needKind))
                    or L.ui("need_horde", "Clear nearby zombies")
                local statusBadge = c.state == "accepted" and L.ui("state_accepted", "ACCEPTED") or L.ui("state_open", "OPEN SOS")
                local row = {
                    rowKind = "sos",
                    id = c.id,
                    channel = c.channel or "emergency",
                    state = c.state,
                    title = string.format("SOS [%s] %s — %s (%d tiles, %dm left)", tostring(c.callsign or "?"), tostring(c.factionName or "?"), tostring(c.town or "?"), dist, minsLeft),
                    subtitle = tostring(c.text or "") .. " | " .. needTxt,
                    meta = statusBadge,
                    x = c.x,
                    y = c.y,
                    callsign = c.callsign,
                    mapLabel = string.format("SOS %s [%s]", tostring(c.callsign or "?"), tostring(c.kind or "sos")),
                }
                self.list:addItem(row.title, row)
            end
        elseif self.activeTab == "dispatch" then
            for _, d in ipairs(cl and cl.dispatches or {}) do
                if d.state == "ready" then
                    local row = {
                        rowKind = "drop",
                        id = d.id,
                        channel = "trade",
                        title = L.ui("drop_ready_title", "[READY DROP] {callsign} near {town} ({x},{y})", { callsign = d.callsign, town = d.town, x = d.x, y = d.y }),
                        subtitle = L.ui("drop_ready_sub", "Supply courier is waiting at the drop coordinates. Approach within 25 tiles and click Claim."),
                        meta = L.ui("state_ready", "READY"),
                        x = d.x,
                        y = d.y,
                        mapLabel = "Supply Drop " .. tostring(d.callsign or ""),
                    }
                    self.list:addItem(row.title, row)
                end
            end
            for _, pkg in ipairs(A.Catalog.PACKAGES) do
                local name = L.ui(pkg.id, pkg.id)
                local desc = L.ui(pkg.id .. "_desc", "Airwaves supply delivery to nearby road point.")
                local row = {
                    rowKind = "pkg",
                    id = pkg.id,
                    channel = pkg.channel or "trade",
                    title = string.format("%s — %s: %d", name, L.ui("cost_label", "Credit"), pkg.cost),
                    subtitle = desc,
                    meta = A.freqMhz(A.channelFreq(pkg.channel)),
                }
                self.list:addItem(row.title, row)
            end
            for _, town in ipairs(A.Catalog.TOWNS) do
                local rep = cl and cl.intel and cl.intel[town.id] or nil
                local sub = rep and L.ui("intel_summary", "Squads: {squads} · Outposts: {outposts} · Convoys: {caravans} · Threat: {danger}", {
                    squads = rep.squads, outposts = rep.outposts, caravans = rep.caravans, danger = string.upper(tostring(rep.danger or "low"))
                }) or L.ui("intel_request_hint", "Request tactical recon report for this sector (Cost: 35 Credit).")
                local row = {
                    rowKind = "town",
                    id = town.id,
                    channel = "tactical",
                    title = L.ui("intel_town_title", "[RECON] {town} ({x},{y})", { town = town.name, x = town.x, y = town.y }),
                    subtitle = sub,
                    meta = rep and string.upper(tostring(rep.danger or "LOW")) or "35 CR",
                    x = town.x,
                    y = town.y,
                    mapLabel = "Recon: " .. town.name,
                }
                self.list:addItem(row.title, row)
            end
        end
    end

    function Win:drawRow(box, y, item)
        local row = item.item
        local c = U.palette()
        local isSel = box.selected == item.index
        if isSel then
            box:drawRect(0, y, box.width, box.itemheight - 1, 0.92, c.selected[1], c.selected[2], c.selected[3])
        else
            box:drawRect(0, y, box.width, box.itemheight - 1, 0.65, c.panel[1], c.panel[2], c.panel[3])
        end
        box:drawRectBorder(0, y, box.width, box.itemheight, 0.7, c.panelEdge[1], c.panelEdge[2], c.panelEdge[3])
        local barCol = U.channelColor(row.channel, c)
        if row.rowKind == "sos" then barCol = row.state == "accepted" and c.warn or c.bad end
        if row.rowKind == "drop" then barCol = c.good end
        box:drawRect(0, y, 4, box.itemheight - 1, 1, barCol[1], barCol[2], barCol[3])

        U.text(box, U.fit(row.title or "", box.width - 130, UIFont.Small), 12, y + 7, c.name, UIFont.Small)
        U.text(box, U.fit(row.subtitle or "", box.width - 30, UIFont.Small), 12, y + 29, c.text, UIFont.Small)
        if row.meta and row.meta ~= "" then
            local tw = type(getTextManager) == "function" and getTextManager():MeasureStringX(UIFont.Small, row.meta) or (#row.meta * 7)
            U.text(box, row.meta, box.width - 18 - tw, y + 7, barCol, UIFont.Small)
        end
        return y + box.itemheight
    end

    function Win:prerender()
        U.window(self)
        ISCollapsableWindow.prerender(self)
        local c = U.palette()
        U.panel(self, 12, 26, self.width - 24, 70, c)
        self:drawRect(12, 26, 3, 70, 1, c.accent[1], c.accent[2], c.accent[3])

        local p = player0(self.playerNum)
        local scan = A.RadioCheck.scanPlayerRadios(p)
        local credit = A.RadioCheck.countPlayerCredit(p)
        local canWrite = A.RadioCheck.canWriteOnMap(p)

        U.text(self, L.ui("header_title", "KNOX COUNTY AIRWAVES & CONTRACTS"), 22, 32, c.accent, UIFont.Small)
        local radioStatus
        local radioColor = c.good
        if scan.best ~= nil and scan.hasPowered then
            radioStatus = L.ui("radio_status_on", "Radio: {name} ({freq}){hp}", {
                name = scan.best.name,
                freq = A.freqMhz(scan.best.channel),
                hp = scan.hasHighPower and " [TX+]" or "",
            })
        elseif scan.hasRadio then
            radioStatus = L.ui("radio_status_off", "Radio OFF — turn on a radio or click a frequency below")
            radioColor = c.warn
        else
            radioStatus = L.ui("radio_status_none", "No radio found in inventory, hands, vehicle, or nearby")
            radioColor = c.bad
        end
        U.text(self, U.fit(radioStatus, self.width - 44, UIFont.Medium), 22, 50, radioColor, UIFont.Medium)

        local subLine = L.ui("header_meta", "Barter Credit: {credit} · Writing Tool: {pen}", {
            credit = tostring(credit),
            pen = canWrite and L.ui("pen_yes", "Ready") or L.ui("pen_no", "None"),
        })
        U.text(self, U.fit(subLine, self.width - 44, UIFont.Small), 22, 74, c.muted, UIFont.Small)

        for id, btn in pairs(self.tabButtons or {}) do
            U.button(btn, id == self.activeTab)
        end

        local row = self:selectedRow()
        if self.activeTab == "log" then
            self.btnPrimary:setTitle(L.ui("btn_tune_selected", "Tune Radio"))
            self.btnPrimary:setEnable(row ~= nil)
            self.btnSecondary:setTitle(L.ui("btn_scan", "Scan Airwaves"))
            self.btnSecondary:setEnable(true)
        elseif self.activeTab == "sos" then
            self.btnPrimary:setTitle(L.ui("btn_accept_sos", "Accept SOS Contract"))
            self.btnPrimary:setEnable(row ~= nil and row.state == "open")
            self.btnSecondary:setTitle(L.ui("btn_fulfill_sos", "Fulfill / Deliver Aid"))
            self.btnSecondary:setEnable(row ~= nil)
        elseif self.activeTab == "dispatch" then
            if row and row.rowKind == "drop" then
                self.btnPrimary:setTitle(L.ui("btn_claim_drop", "Claim Delivered Supplies"))
            elseif row and row.rowKind == "town" then
                self.btnPrimary:setTitle(L.ui("btn_request_intel", "Request Town Intel (35 CR)"))
            else
                self.btnPrimary:setTitle(L.ui("btn_order_drop", "Order Supply Drop"))
            end
            self.btnPrimary:setEnable(row ~= nil)
            self.btnSecondary:setTitle(L.ui("btn_call_caravan", "Hail / Call Caravan"))
            self.btnSecondary:setEnable(true)
        end
        local hasCoords = row ~= nil and tonumber(row.x) ~= nil and tonumber(row.y) ~= nil
        self.btnMark:setEnable(hasCoords)
        self.btnCenter:setEnable(hasCoords)
    end

    function Win:close()
        self:setVisible(false)
        self:removeFromUIManager()
        if A.Client and A.Client.window == self then
            A.Client.window = nil
        end
    end
end

function U.openWindow(playerNum, tabId)
    if not Win then return false end
    if A.Client and A.Client.window then
        if tabId and A.Client.window.activeTab ~= tabId then
            A.Client.window.activeTab = tabId
            A.Client.window:refresh()
            return true
        end
        A.Client.window:close()
        return false
    end
    local sw = type(getCore) == "function" and getCore():getScreenWidth() or 1280
    local sh = type(getCore) == "function" and getCore():getScreenHeight() or 720
    local width = math.min(720, sw - 40)
    local height = math.min(540, sh - 60)
    local x = math.floor((sw - width) / 2)
    local y = math.floor((sh - height) / 2)
    local win = Win:new(x, y, width, height)
    win.playerNum = tonumber(playerNum) or 0
    win.activeTab = tabId or "log"
    win:setTitle(L.ui("window_title", "A-Life: Airwaves & Contracts"))
    win:initialise()
    win:addToUIManager()
    win:setVisible(true)
    win:setResizable(false)
    if A.Client then A.Client.window = win end
    return true, win
end

return U.openWindow
