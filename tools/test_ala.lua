-- Comprehensive lupa simulation test suite for A-Life: Airwaves & Contracts (ALifeAirwaves).
local failed = 0
local passed = 0

local function check(cond, label)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL:", label)
    end
end

package.path = MOD_ROOT .. "/42/media/lua/shared/?.lua;"
    .. MOD_ROOT .. "/42/media/lua/server/?.lua;"
    .. MOD_ROOT .. "/42/media/lua/client/?.lua;"
    .. package.path

-- Mock PZ engine & UI environment
local nowMs = 100000
function getTimestampMs() return nowMs end
function ZombRand(n) return 0 end
function ZombRandFloat(a, b) return a or 0 end
function isServer() return false end
function isClient() return false end
function getText(key) return TRANSLATIONS[key] or key end
function instanceof(obj, cls) return type(obj) == "table" and obj.__class == cls end

UIFont = { Small = "Small", Medium = "Medium", Large = "Large" }
Keyboard = { KEY_F9 = 67 }
ItemTag = { WRITE = "WRITE" }
ChannelCategory = { Radio = "Radio", Emergency = "Emergency", Amateur = "Amateur", Military = "Military" }

function getTextManager()
    return {
        MeasureStringX = function(_, _, s) return #(tostring(s or "")) * 7 end,
        getFontHeight = function() return 16 end,
    }
end

function getCore()
    return {
        getScreenWidth = function() return 1280 end,
        getScreenHeight = function() return 720 end,
    }
end

local haloMessages = {}
HaloTextHelper = {
    addText = function(_, text) haloMessages[#haloMessages + 1] = text end,
}

-- Mock ZomboidRadio & DynamicRadio
DynamicRadio = { channels = {}, scripts = {}, cache = {} }
local registeredChannels = {}
DynamicRadioChannel = {
    new = function(name, freq, cat, uuid)
        return {
            name = name,
            freq = freq,
            cat = cat,
            uuid = uuid,
            aired = {},
            GetFrequency = function(self) return self.freq end,
            setAiringBroadcast = function(self, bc) self.aired[#self.aired + 1] = bc end,
        }
    end,
}
RadioBroadCast = {
    new = function(id, a, b)
        return {
            id = id,
            lines = {},
            AddRadioLine = function(self, rl) self.lines[#self.lines + 1] = rl end,
        }
    end,
}
RadioLine = {
    new = function(text, r, g, b) return { text = text, r = r, g = g, b = b } end,
}
local mockScriptManager = {
    getRadioChannel = function(_, uuid) return registeredChannels[uuid] end,
    AddChannel = function(_, ch) registeredChannels[ch.uuid] = ch end,
}
function getZomboidRadio()
    return {
        getScriptManager = function() return mockScriptManager end,
    }
end

function getGameTime()
    return {
        getNightsSurvived = function() return 4 end,
        getTimeOfDay = function() return 14.5 end,
    }
end

-- Mock Inventory & Player
local function makeItem(fullType, opts)
    opts = opts or {}
    local item = {
        __class = opts.cls or "InventoryItem",
        fullType = fullType,
        fav = opts.fav or false,
        getFullType = function(self) return self.fullType end,
        getType = function(self) return string.gsub(self.fullType, "^[^%.]+%.", "") end,
        getName = function(self) return opts.name or self.fullType end,
        isFavorite = function(self) return self.fav end,
    }
    if opts.radio then
        item.__class = "Radio"
        local dd = {
            turnedOn = opts.turnedOn ~= false,
            power = opts.power or 0.8,
            battery = true,
            channel = opts.channel or 94200,
            txRange = opts.txRange or 5000,
            highTier = opts.highTier ~= false,
            deviceName = opts.name or "Military Walkie-Talkie",
            getIsTurnedOn = function(self) return self.turnedOn end,
            setIsTurnedOn = function(self, v) self.turnedOn = v end,
            getPower = function(self) return self.power end,
            getIsBatteryPowered = function(self) return self.battery end,
            getChannel = function(self) return self.channel end,
            setChannel = function(self, ch) self.channel = ch end,
            getTransmitRange = function(self) return self.txRange end,
            getIsHighTier = function(self) return self.highTier end,
            getDeviceName = function(self) return self.deviceName end,
        }
        item.deviceData = dd
        item.getDeviceData = function(self) return self.deviceData end
    end
    return item
end

local invList = {}
local mockInventory = {
    getItems = function()
        return {
            size = function() return #invList end,
            get = function(_, idx) return invList[idx + 1] end,
        }
    end,
    AddItem = function(_, ft)
        local it = makeItem(ft)
        invList[#invList + 1] = it
        return it
    end,
    Remove = function(_, target)
        for i, it in ipairs(invList) do
            if it == target then
                table.remove(invList, i)
                return true
            end
        end
        return false
    end,
    containsTagRecurse = function(_, tag)
        if tag == "WRITE" then
            for _, it in ipairs(invList) do
                if it.fullType == "Base.Pen" or it.fullType == "Base.Pencil" then return true end
            end
        end
        return false
    end,
    containsTypeRecurse = function(_, ft)
        for _, it in ipairs(invList) do
            if it.fullType == ft then return true end
        end
        return false
    end,
}

local mockPlayer = {
    x = 10630,
    y = 9780,
    z = 0,
    getX = function(self) return self.x end,
    getY = function(self) return self.y end,
    getZ = function(self) return self.z end,
    getUsername = function() return "TestSurvivor" end,
    getPlayerNum = function() return 0 end,
    isDead = function() return false end,
    isEquipped = function() return false end,
    isHandItem = function() return false end,
    getPrimaryHandItem = function() return nil end,
    getSecondaryHandItem = function() return nil end,
    getVehicle = function() return nil end,
    getInventory = function() return mockInventory end,
    playSoundLocal = function() end,
    Say = function(_, txt) haloMessages[#haloMessages + 1] = txt end,
}

function getSpecificPlayer(num)
    if (num or 0) == 0 then return mockPlayer end
    return nil
end
function getPlayer() return mockPlayer end

local cellZombies = {}
function getCell()
    return {
        getGridSquare = function() return nil end,
        getZombieList = function()
            return {
                size = function() return #cellZombies end,
                get = function(_, i) return cellZombies[i + 1] end,
            }
        end,
    }
end

-- Mock UI base classes
local function makeUIElement(x, y, w, h)
    return {
        x = x or 0, y = y or 0, width = w or 600, height = h or 400,
        children = {},
        visible = true,
        enable = true,
        instantiate = function(self)
            self.javaObject = self.javaObject or {}
            if type(self.createChildren) == "function" and not self._childrenCreated then
                self._childrenCreated = true
                self:createChildren()
            end
        end,
        addChild = function(self, c)
            self.children[#self.children + 1] = c
            if type(c.instantiate) == "function" and not c.javaObject then c:instantiate() end
        end,
        addToUIManager = function(self)
            if type(self.instantiate) == "function" and not self.javaObject then self:instantiate() end
        end,
        removeFromUIManager = function() end,
        setVisible = function(self, v) self.visible = v end,
        setResizable = function() end,
        setTitle = function(self, t) self.title = t end,
        setEnable = function(self, e) self.enable = e end,
        drawRect = function() end,
        drawRectBorder = function() end,
        drawText = function() end,
    }
end

ISCollapsableWindow = {
    derive = function(_, name)
        local cls = { Type = name }
        cls.__index = cls
        function cls:new(x, y, w, h)
            local o = makeUIElement(x, y, w, h)
            setmetatable(o, cls)
            return o
        end
        function cls:createChildren() end
        function cls:prerender() end
        function cls:initialise() end
        return cls
    end,
    createChildren = function() end,
    prerender = function() end,
}

ISButton = {
    new = function(_, x, y, w, h, title, target, onclick)
        local b = makeUIElement(x, y, w, h)
        b.title = title
        b.target = target
        b.onclick = onclick
        b.initialise = function() end
        b.setTitle = function(self, t) self.title = t end
        b.click = function(self) if self.enable and self.onclick then self.onclick(self.target, self) end end
        return b
    end,
}

ISScrollingListBox = {
    new = function(_, x, y, w, h)
        local l = makeUIElement(x, y, w, h)
        l.items = {}
        l.selected = 1
        l.itemheight = 48
        l.initialise = function() end
        l.clear = function(self) self.items = {} end
        l.addItem = function(self, text, item)
            local entry = { text = text, item = item, index = #self.items + 1 }
            self.items[#self.items + 1] = entry
            return entry
        end
        return l
    end,
}

-- Mock WorldMap & Symbols API
local addedMapNotes = {}
ISWorldMap_instance = {
    mapAPI = {
        worldToUIX = function(_, x) return (x - 10000) * 0.2 end,
        worldToUIY = function(_, _, y) return (y - 9000) * 0.2 end,
        centerOn = function(_, x, y) ISWorldMap_instance.centered = { x = x, y = y } end,
        getSymbolsAPIv2 = function()
            return {
                getDefaultTextLayerID = function() return "map-note" end,
                addUntranslatedText = function(_, text, layer, x, y)
                    addedMapNotes[#addedMapNotes + 1] = { text = text, layer = layer, x = x, y = y }
                    return { setRGBA = function() end, setAnchor = function() end }
                end,
            }
        end,
    },
}
ISWorldMap = {
    render = function() return true end,
    ShowWorldMap = function(_, x, y) ISWorldMap_instance.centered = { x = x, y = y } end,
}
ISMiniMapInner = {
    render = function() return true end,
}

-- Mock PZAPI.ModOptions
local modOptionsCreated = nil
PZAPI = {
    ModOptions = {
        create = function(_, id, name)
            local optObj = {
                id = id,
                name = name,
                items = {},
                addDescription = function() end,
                addKeyBind = function(self, k, _, def)
                    local o = { id = k, val = def, getValue = function(s) return s.val end }
                    self.items[k] = o
                    return o
                end,
                addTickBox = function(self, k, _, def)
                    local o = { id = k, val = def, getValue = function(s) return s.val end }
                    self.items[k] = o
                    return o
                end,
                addComboBox = function(self, k)
                    local o = { id = k, val = 1, addItem = function() end, getValue = function(s) return s.val end }
                    self.items[k] = o
                    return o
                end,
            }
            modOptionsCreated = optObj
            return optObj
        end,
    },
}

-- Mock Events
Events = {}
for _, evName in ipairs({
    "OnGameStart", "OnServerStarted", "OnTick", "EveryOneMinute", "OnClientCommand",
    "OnLoadRadioScripts", "OnFillInventoryObjectContextMenu", "OnFillWorldObjectContextMenu",
    "OnServerCommand", "OnKeyPressed",
}) do
    local list = {}
    Events[evName] = {
        list = list,
        Add = function(fn) list[#list + 1] = fn end,
        Remove = function(fn)
            for i = #list, 1, -1 do
                if list[i] == fn then table.remove(list, i) end
            end
        end,
    }
end

-- Mock ProjectALife & ALifeCaravans
local buckets = {}
local spawnedGroups = {}
local helpedFactions = {}
ProjectALife = {
    Persistence = {
        bucket = function(name, defaults)
            buckets[name] = buckets[name] or defaults
            return buckets[name]
        end,
        touch = function() end,
    },
    Catalog = {
        current = {
            factionOrder = {
                { id = "rangers", general = { name = "Knox Rangers" } },
                { id = "medics", general = { name = "Relief Medics" } },
            },
            npcOrder = {
                { id = "npc_1", general = { name = "Elena Vance", faction = "rangers" } },
                { id = "npc_2", general = { name = "Marcus Cole", faction = "rangers" } },
                { id = "npc_3", general = { name = "Dr. Lin", faction = "medics" } },
            },
        },
        faction = function(id)
            if id == "rangers" then return { id = "rangers", general = { name = "Knox Rangers" } } end
            if id == "medics" then return { id = "medics", general = { name = "Relief Medics" } } end
            return nil
        end,
    },
    SquadLedger = {
        list = function()
            return {
                { id = "sq1", factionId = "rangers", x = 10660, y = 9810, size = 3, state = "active" },
            }
        end,
    },
    OutpostRegistry = {
        list = function()
            return {
                { id = "op1", factionId = "medics", x = 10590, y = 9750 },
            }
        end,
    },
    Speech = {
        playerKey = function() return "sp:0" end,
        nearestTown = function() return "Muldraugh" end,
        say = function(_, text) haloMessages[#haloMessages + 1] = "NPC:" .. tostring(text) return true end,
        findShell = function()
            return { getX = function() return 10640 end, getY = function() return 9785 end, getZ = function() return 0 end }
        end,
    },
    Reputation = {
        onPlayerHelped = function(_, facId) helpedFactions[#helpedFactions + 1] = facId end,
    },
    DebugService = {
        rawSpawn = function(_, args)
            spawnedGroups[#spawnedGroups + 1] = args
            return { ok = true, uids = { "uid_1", "uid_2" } }
        end,
    },
}

ALifeCaravans = {
    Ledger = {
        list = function()
            return {
                {
                    id = "caravan:1",
                    name = "Free Traders",
                    factionId = "rangers",
                    factionName = "Knox Rangers",
                    callsign = "Bravo",
                    destName = "West Point",
                    x = 10700,
                    y = 9820,
                    state = "rendered",
                    hostile = false,
                },
            }
        end,
        addFavor = function() end,
    },
    Director = {
        halt = function(c, sec, reason) c.halted = true c.haltReason = reason end,
    },
}

SandboxVars = {
    ALifeAirwaves = {
        Enabled = true,
        BroadcastIntervalMinutes = 4,
        SOSContractIntervalMinutes = 8,
        SOSTimeoutMinutes = 15,
        RewardMultiplier = 100,
        SupplyDispatchCooldownMinutes = 12,
        IntelCooldownMinutes = 5,
        AutoMapMarkers = true,
        RequirePoweredRadio = true,
        EmergencyFreqKhz = 94200,
        TradeFreqKhz = 101600,
        TacticalFreqKhz = 106400,
        Debug = true,
    },
}

-- Load all mod modules
require "ALifeAirwaves/00_ALA_Core"
require "ALifeAirwaves/01_ALA_Lines"
require "ALifeAirwaves/02_ALA_RadioCheck"
require "ALifeAirwaves/03_ALA_Catalog"
require "ALifeAirwaves/ALA_Ledger"
require "ALifeAirwaves/ALA_ZomboidRadio"
require "ALifeAirwaves/ALA_Director"
require "ALifeAirwaves/ALA_Ops"
require "ALifeAirwaves/ALA_Boot"
require "ALifeAirwaves/ALA_Style"
require "ALifeAirwaves/ALA_Map"
require "ALifeAirwaves/ALA_AirwavesWindow"
require "ALifeAirwaves/ALA_Client"

local A = ALifeAirwaves

-- 1. Check translation catalog keys
for _, key in ipairs(A.Lines.keys()) do
    local val = getText(key)
    check(type(val) == "string" and val ~= "" and val ~= key, "line key exists: " .. key)
end

-- 2. Boot & ZomboidRadio channel registration
check(A.Boot.install() == true, "Boot.install succeeds")
check(A.Boot.installed == true, "Boot.installed flag set")
check(registeredChannels["ALA-EMRG-942"] ~= nil, "Emergency channel 94.2 MHz registered")
check(registeredChannels["ALA-TRAD-1016"] ~= nil, "Trade channel 101.6 MHz registered")
check(registeredChannels["ALA-TACT-1064"] ~= nil, "Tactical channel 106.4 MHz registered")
check(#A.Ledger.listBroadcasts() >= 1, "Initial broadcast emitted on boot")

-- 3. Player radio & writing tool checks
invList = {}
local scan0 = A.RadioCheck.scanPlayerRadios(mockPlayer)
check(scan0.hasRadio == false and scan0.hasPowered == false, "No radio initially")
check(A.RadioCheck.canWriteOnMap(mockPlayer) == false, "Cannot write on map without pen/pencil")

local radioItem = makeItem("Radio.WalkieTalkie4", { radio = true, turnedOn = true, power = 0.9, channel = 94200, highTier = true })
local penItem = makeItem("Base.Pen")
invList[#invList + 1] = radioItem
invList[#invList + 1] = penItem

local scan1 = A.RadioCheck.scanPlayerRadios(mockPlayer)
check(scan1.hasRadio == true and scan1.hasPowered == true and scan1.hasHighPower == true, "High-power WalkieTalkie4 detected")
check(A.RadioCheck.canWriteOnMap(mockPlayer) == true, "Pen enables map writing")

-- 4. Tuning radio
local okTune, tunedFreq = A.RadioCheck.tunePlayerRadio(mockPlayer, 101600)
check(okTune == true and tunedFreq == 101600 and radioItem.deviceData.channel == 101600, "Radio tuned to 101.6 MHz")

-- 5. Broadcast emission & auto map marking
local notesBefore = #addedMapNotes
local b1 = A.Director.emitBroadcast(nowMs, "air_caravan")
check(b1 ~= nil and b1.channel == "trade", "Caravan broadcast emitted on trade channel")
check(#addedMapNotes > notesBefore, "Broadcast coordinates auto-marked on WorldMapSymbols when holding Pen")

-- 6. SOS Contract lifecycle (create -> accept -> materialize -> fulfill -> reward)
local sosMed = A.Director.createSOS(nowMs, "medical", mockPlayer)
check(sosMed ~= nil and sosMed.state == "open" and sosMed.needKind == "medical", "Medical SOS contract created")
local okAcc = A.Director.acceptSOS(mockPlayer, sosMed.id)
check(okAcc == true and sosMed.state == "accepted" and sosMed.owner == "sp:0", "SOS contract accepted by player")

-- Move player to SOS coordinates and give bandages
mockPlayer.x, mockPlayer.y = sosMed.x, sosMed.y
invList[#invList + 1] = makeItem("Base.Bandage")
invList[#invList + 1] = makeItem("Base.Bandage")
local okFulfill, givenRewards = A.Director.fulfillSOS(mockPlayer, sosMed.id)
check(okFulfill == true and sosMed.state == "completed", "Medical SOS contract fulfilled")
check(type(givenRewards) == "table" and #givenRewards >= 1, "SOS completion granted physical reward items")
check(A.Ledger.favor("sp:0", sosMed.factionId) >= 3, "SOS completion increased faction favor")
check(#helpedFactions >= 1, "ProjectALife.Reputation.onPlayerHelped called")
local okDup = A.Director.completeSOS(sosMed, mockPlayer)
check(okDup == false, "Duplicate SOS payout blocked by receipt")

-- 7. Horde SOS contract auto-completion when zombies cleared
local sosHorde = A.Director.createSOS(nowMs, "horde", mockPlayer)
mockPlayer.x, mockPlayer.y = sosHorde.x, sosHorde.y
cellZombies = {
    { getX = function() return sosHorde.x + 2 end, getY = function() return sosHorde.y + 2 end, getZ = function() return 0 end, isDead = function() return false end, getModData = function() return {} end },
}
A.Director.acceptSOS(mockPlayer, sosHorde.id)
local okPremature = A.Director.fulfillSOS(mockPlayer, sosHorde.id)
check(okPremature == false, "Horde SOS refuses completion while zombies remain nearby")
cellZombies = {}
A.Director.tickSOS(nowMs + 1000, { mockPlayer })
check(sosHorde.state == "completed", "Horde SOS auto-completes once nearby zombies are cleared")

-- 8. Supply Dispatch & Claim
for _ = 1, 12 do invList[#invList + 1] = makeItem("Base.Money") end
check(A.RadioCheck.countPlayerCredit(mockPlayer) >= 120, "Player barter credit counted accurately")
local okDisp, disp = A.Director.requestDispatch(mockPlayer, "pkg_medical")
check(okDisp == true and disp ~= nil and disp.state == "ready", "Medical supply drop dispatched")
mockPlayer.x, mockPlayer.y = disp.x, disp.y
local okClaim, claimedItems = A.Director.claimDispatch(mockPlayer, disp.id)
check(okClaim == true and disp.state == "claimed" and #claimedItems >= 3, "Supply drop claimed at coordinates")

-- 9. Call Caravan integration with ALifeCaravans
local okCall, calledCaravan = A.Director.callCaravan(mockPlayer)
check(okCall == true and calledCaravan ~= nil and calledCaravan.halted == true, "Calling caravan hails nearby ALifeCaravans convoy")

-- 10. Town Recon Intel
for _ = 1, 5 do invList[#invList + 1] = makeItem("Base.Money") end
local okIntel, report = A.Director.requestIntel(mockPlayer, "Muldraugh")
check(okIntel == true and report ~= nil and report.townName == "Muldraugh", "Town recon intel generated for Muldraugh")
check(report.squads >= 1 and report.outposts >= 1 and report.caravans >= 1, "Recon intel counts live squads, outposts, and caravans")

-- 11. Client UI window & Map overlay
A.Map.install()
local drawn = A.Map.drawOn(makeUIElement(0, 0, 800, 600), ISWorldMap_instance.mapAPI, true, 5)
check(drawn >= 1, "Map overlay draws beacons and custom marks")

local opened, win = A.Style.openWindow(0, "log")
check(opened == true and win ~= nil and win.activeTab == "log", "ALA_AirwavesWindow opens on log tab")
win:prerender()
check(#win.list.items >= 1, "Airwaves Log tab populated with broadcasts")
win:onMarkMap()
win:onCenterMap()
check(ISWorldMap_instance.centered ~= nil, "Show on Map centers world map")

win:onSelectTab({ tabId = "log" })
win:prerender()
if #win.list.items >= 1 then
    win.list.doDrawItem(win.list, 0, win.list.items[1])
end
win:onFreqBar(win.freqButtons[1])
win:onFreqBar(win.freqButtons[4])

win:onSelectTab({ tabId = "sos" })
local sosAmmo = A.Director.createSOS(nowMs, "ammo", mockPlayer)
local sosBrk = A.Director.createSOS(nowMs, "breakdown", mockPlayer)
win:refresh()
win:prerender()
check(win.activeTab == "sos" and #win.list.items >= 2, "Switched to SOS & Contracts tab with active SOS")
win.list.doDrawItem(win.list, 0, win.list.items[1])

-- Fulfill ammo and breakdown SOS
mockPlayer.x, mockPlayer.y = sosAmmo.x, sosAmmo.y
invList[#invList + 1] = makeItem("Base.Bullets9mmBox")
check(A.Director.fulfillSOS(mockPlayer, sosAmmo.id) == true, "Ammo SOS fulfilled with Bullets9mmBox")

mockPlayer.x, mockPlayer.y = sosBrk.x, sosBrk.y
invList[#invList + 1] = makeItem("Base.PetrolCan")
check(A.Director.fulfillSOS(mockPlayer, sosBrk.id) == true, "Breakdown SOS fulfilled with PetrolCan")

win:onSelectTab({ tabId = "dispatch" })
win:prerender()
check(win.activeTab == "dispatch" and #win.list.items >= 6, "Switched to Supply & Intel tab with packages & towns")
win.list.doDrawItem(win.list, 0, win.list.items[1])

-- Context menu tests
local menuOpts = {}
local mockCtx = {
    addOption = function(_, label, target, fn)
        local o = { label = label, target = target, fn = fn }
        menuOpts[#menuOpts + 1] = o
        return o
    end,
    getNew = function(self) return self end,
    addSubMenu = function() end,
}
A.Client.fillInventoryMenu(0, mockCtx, { radioItem })
check(#menuOpts >= 1, "Inventory right-click menu on radio adds Airwaves option")
A.Client.fillWorldMenu(0, mockCtx, {}, false)
check(#menuOpts >= 5, "World right-click menu adds Airwaves submenu options")

-- Sandbox live refresh test
SandboxVars.ALifeAirwaves.RewardMultiplier = 200
SandboxVars.ALifeAirwaves.EmergencyFreqKhz = 95000
A.refreshSettings()
check(A.settings.rewardMultiplier == 200 and A.channelFreq("emergency") == 95000, "Sandbox settings live-refresh in-game")
SandboxVars.ALifeAirwaves.RewardMultiplier = 100
SandboxVars.ALifeAirwaves.EmergencyFreqKhz = 94200
A.refreshSettings()

win:close()
check(A.Client.window == nil, "Window closes cleanly")

-- 12. Hotkey & ModOptions
check(modOptionsCreated ~= nil and modOptionsCreated.id == "ALifeAirwaves", "PZAPI.ModOptions registered")
A.Client.onKeyPressed(Keyboard.KEY_F9)
check(A.Client.window ~= nil, "F9 hotkey opens ALA_AirwavesWindow")
A.Client.onKeyPressed(Keyboard.KEY_F9)
check(A.Client.window == nil, "F9 hotkey toggles ALA_AirwavesWindow closed")

A.status()
print(string.format("  passed = %d, failed = %d", passed, failed))
return failed
