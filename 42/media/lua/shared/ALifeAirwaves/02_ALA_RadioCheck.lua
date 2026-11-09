-- A-Life: Airwaves & Contracts - radio device inspection, tuning, map writing
-- checks, and authoritative inventory exchange for SOS supplies and dispatches.

require "ALifeAirwaves/00_ALA_Core"

local A = ALifeAirwaves
local R = {}
A.RadioCheck = R

R.WRITING_TYPES = {
    ["Base.Pen"] = true, ["Base.Pencil"] = true, ["Base.RedPen"] = true, ["Base.BluePen"] = true,
    ["Base.GreenPen"] = true, ["Base.Crayons"] = true, ["Base.PencilSpiffo"] = true, ["Base.PenMultiColor"] = true,
    ["Pen"] = true, ["Pencil"] = true, ["RedPen"] = true, ["BluePen"] = true, ["GreenPen"] = true, ["Crayons"] = true,
}

R.HIGH_POWER_TYPES = {
    ["Radio.WalkieTalkie4"] = true, ["Radio.WalkieTalkie5"] = true, ["Radio.WalkieTalkieMakeShift"] = true,
    ["Radio.HamRadio1"] = true, ["Radio.HamRadio2"] = true, ["Radio.HamRadioMakeShift"] = true,
    ["Base.WalkieTalkie4"] = true, ["Base.WalkieTalkie5"] = true, ["Base.WalkieTalkieMakeShift"] = true,
    ["Base.HamRadio1"] = true, ["Base.HamRadio2"] = true, ["Base.HamRadioMakeShift"] = true,
    ["Base.ManPackRadio"] = true, ["Radio.ManPackRadio"] = true,
    ["WalkieTalkie4"] = true, ["WalkieTalkie5"] = true, ["WalkieTalkieMakeShift"] = true,
    ["HamRadio1"] = true, ["HamRadio2"] = true, ["HamRadioMakeShift"] = true, ["ManPackRadio"] = true,
}

R.CREDIT_VALUES = {
    ["Base.Money"] = 10, ["Base.Cigarettes"] = 12, ["Base.GoldBar"] = 250, ["Base.SilverBar"] = 120,
    ["Base.WristWatch_Right_ClassicGold"] = 45, ["Base.Necklace_Gold"] = 50, ["Base.Ring_Right_MiddleFinger_Gold"] = 35,
    ["Base.Antibiotics"] = 60, ["Base.FirstAidKit"] = 80, ["Base.Bandage"] = 10, ["Base.Pills"] = 20,
    ["Base.Disinfectant"] = 25, ["Base.Bullets9mmBox"] = 50, ["Base.Bullets45Box"] = 50, ["Base.ShotgunShellsBox"] = 55,
    ["Base.556Box"] = 70, ["Base.308Box"] = 70, ["Base.PetrolCan"] = 45, ["Base.TinnedBeans"] = 15,
    ["Base.CannedCornedBeef"] = 18, ["Base.MRE"] = 25, ["Base.Whiskey"] = 30, ["Base.Coffee"] = 20,
    ["Base.Battery"] = 12, ["Base.DuctTape"] = 15, ["Base.Wrench"] = 20, ["Base.Screwdriver"] = 15,
}

local function safeCall(obj, method, ...)
    if obj == nil then return nil end
    local fn = obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, obj, ...)
    if ok then return res end
    return nil
end

function R.itemFullType(item)
    return safeCall(item, "getFullType") or safeCall(item, "getType") or ""
end

local function inspectDevice(device, sourceKind)
    if device == nil then return nil end
    local dd = safeCall(device, "getDeviceData")
    if dd == nil then return nil end
    local turnedOn = safeCall(dd, "getIsTurnedOn") == true
    local power = tonumber(safeCall(dd, "getPower")) or 0
    local isBattery = safeCall(dd, "getIsBatteryPowered")
    local hasPower = power > 0.001 or isBattery == false or sourceKind == "vehicle" or sourceKind == "world"
    local channel = tonumber(safeCall(dd, "getChannel")) or 94200
    local txRange = tonumber(safeCall(dd, "getTransmitRange")) or 0
    local highTier = safeCall(dd, "getIsHighTier") == true
    local fullType = R.itemFullType(device)
    local shortType = safeCall(device, "getType") or ""
    local deviceName = tostring(safeCall(dd, "getDeviceName") or safeCall(device, "getName") or "Radio")
    local isHighPower = highTier or txRange >= 4000 or sourceKind == "vehicle" or sourceKind == "world"
        or R.HIGH_POWER_TYPES[fullType] == true or R.HIGH_POWER_TYPES[shortType] == true
        or string.find(string.lower(deviceName), "ham", 1, true) ~= nil
        or string.find(string.lower(deviceName), "military", 1, true) ~= nil
        or string.find(string.lower(deviceName), "tactical", 1, true) ~= nil
    return {
        device = device,
        deviceData = dd,
        sourceKind = sourceKind,
        name = deviceName,
        fullType = fullType,
        turnedOn = turnedOn,
        hasPower = hasPower,
        active = turnedOn and hasPower,
        channel = channel,
        highPower = isHighPower,
        txRange = txRange,
    }
end

function R.scanPlayerRadios(player)
    local out = {
        hasRadio = false,
        hasPowered = false,
        hasHighPower = false,
        tunedChannel = nil,
        best = nil,
        devices = {},
    }
    if player == nil then return out end
    local seen = {}
    local function consider(dev, kind)
        if dev == nil or seen[dev] then return end
        seen[dev] = true
        local info = inspectDevice(dev, kind)
        if info == nil then return end
        out.hasRadio = true
        out.devices[#out.devices + 1] = info
        if info.active then
            out.hasPowered = true
            if info.highPower then out.hasHighPower = true end
        elseif not A.settings.requirePoweredRadio then
            out.hasPowered = true
            if info.highPower then out.hasHighPower = true end
        end
        if out.best == nil then
            out.best = info
        elseif info.active and not out.best.active then
            out.best = info
        elseif info.active == out.best.active and info.highPower and not out.best.highPower then
            out.best = info
        end
    end

    consider(safeCall(player, "getPrimaryHandItem"), "hand")
    consider(safeCall(player, "getSecondaryHandItem"), "hand")

    local inv = safeCall(player, "getInventory")
    local items = inv and safeCall(inv, "getItems") or nil
    if items ~= nil and type(items.size) == "function" then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item ~= nil and ((type(instanceof) == "function" and instanceof(item, "Radio")) or type(item.getDeviceData) == "function") then
                consider(item, "inventory")
            end
        end
    end

    local vehicle = safeCall(player, "getVehicle")
    if vehicle ~= nil then
        local part = safeCall(vehicle, "getPartById", "Radio")
        if part ~= nil then consider(part, "vehicle") end
    end

    local px, py, pz = A.xyz(player)
    local cell = type(getCell) == "function" and getCell() or nil
    if px ~= nil and cell ~= nil and type(cell.getGridSquare) == "function" then
        local bx, by, bz = math.floor(px), math.floor(py), math.floor(pz or 0)
        for dx = -3, 3 do
            for dy = -3, 3 do
                local sq = cell:getGridSquare(bx + dx, by + dy, bz)
                local objs = sq and safeCall(sq, "getObjects") or nil
                if objs ~= nil and type(objs.size) == "function" then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj ~= nil and ((type(instanceof) == "function" and instanceof(obj, "IsoWaveSignal")) or type(obj.getDeviceData) == "function") then
                            consider(obj, "world")
                        end
                    end
                end
            end
        end
    end

    if out.best ~= nil then
        out.tunedChannel = out.best.channel
    end
    if not A.settings.requirePoweredRadio then
        out.hasPowered = true
        out.hasHighPower = true
    end
    return out
end

function R.canReceive(player, freqKhz)
    if not A.settings.requirePoweredRadio then return true end
    local scan = R.scanPlayerRadios(player)
    if not scan.hasPowered then return false, "no_powered_radio" end
    return true, "ok", scan
end

function R.canTransmit(player, requireHighPower)
    if not A.settings.requirePoweredRadio then return true, "ok" end
    local scan = R.scanPlayerRadios(player)
    if not scan.hasRadio then return false, "no_radio" end
    if not scan.hasPowered then return false, "radio_off" end
    if requireHighPower and not scan.hasHighPower then return false, "weak_radio" end
    return true, "ok", scan
end

function R.tunePlayerRadio(player, freqKhz)
    freqKhz = A.clamp(freqKhz, 88000, 108000, A.settings.emergencyFreqKhz)
    local scan = R.scanPlayerRadios(player)
    local target = scan.best
    if target == nil or target.deviceData == nil then return false, "no_radio" end
    local dd = target.deviceData
    pcall(function()
        if not dd:getIsTurnedOn() then
            dd:setIsTurnedOn(true)
        end
        dd:setChannel(freqKhz)
    end)
    A.metrics.radioTunes = A.metrics.radioTunes + 1
    return true, freqKhz, target.name
end

function R.canWriteOnMap(player)
    if player == nil then return false end
    local inv = safeCall(player, "getInventory")
    if inv == nil then return false end
    local hasWriteTag = false
    pcall(function()
        if ItemTag and ItemTag.WRITE and type(inv.containsTagRecurse) == "function" then
            hasWriteTag = inv:containsTagRecurse(ItemTag.WRITE) == true
        end
    end)
    if hasWriteTag then return true end
    if type(inv.containsTypeRecurse) == "function" then
        for fullType in pairs(R.WRITING_TYPES) do
            local ok, found = pcall(inv.containsTypeRecurse, inv, fullType)
            if ok and found == true then return true end
        end
    end
    local items = safeCall(inv, "getItems")
    if items ~= nil and type(items.size) == "function" then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local ft = R.itemFullType(item)
            local st = safeCall(item, "getType") or ""
            if R.WRITING_TYPES[ft] or R.WRITING_TYPES[st] then return true end
        end
    end
    return false
end

local function isProtectedItem(player, item)
    if item == nil then return true end
    if safeCall(item, "isFavorite") == true then return true end
    if player ~= nil and safeCall(player, "isEquipped", item) == true then return true end
    if player ~= nil and safeCall(player, "isHandItem", item) == true then return true end
    return false
end

function R.itemCreditValue(fullType)
    if type(fullType) ~= "string" then return 0 end
    if R.CREDIT_VALUES[fullType] ~= nil then return R.CREDIT_VALUES[fullType] end
    if ALifeCaravans and ALifeCaravans.Trade and type(ALifeCaravans.Trade.valueOf) == "function" then
        local ok, v = pcall(ALifeCaravans.Trade.valueOf, fullType)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return 0
end

function R.countPlayerCredit(player)
    local inv = safeCall(player, "getInventory")
    local items = inv and safeCall(inv, "getItems") or nil
    if items == nil or type(items.size) ~= "function" then return 0, {} end
    local total = 0
    local usable = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not isProtectedItem(player, item) then
            local ft = R.itemFullType(item)
            local val = R.itemCreditValue(ft)
            if val > 0 then
                total = total + val
                usable[#usable + 1] = { item = item, fullType = ft, value = val }
            end
        end
    end
    table.sort(usable, function(a, b)
        local aMoney = a.fullType == "Base.Money" and 0 or 1
        local bMoney = b.fullType == "Base.Money" and 0 or 1
        if aMoney ~= bMoney then return aMoney < bMoney end
        return a.value < b.value
    end)
    return total, usable
end

function R.spendPlayerCredit(player, requiredCredit)
    requiredCredit = math.max(0, math.floor(tonumber(requiredCredit) or 0))
    if requiredCredit <= 0 then return true, 0 end
    local total, usable = R.countPlayerCredit(player)
    if total < requiredCredit then return false, "insufficient_credit" end
    local inv = safeCall(player, "getInventory")
    if inv == nil then return false, "no_inventory" end
    local paid = 0
    for _, entry in ipairs(usable) do
        if paid >= requiredCredit then break end
        paid = paid + entry.value
        pcall(function()
            inv:Remove(entry.item)
            if type(sendRemoveItemFromContainer) == "function" and A.side() == "server" then
                sendRemoveItemFromContainer(inv, entry.item)
            end
        end)
    end
    return true, paid
end

function R.givePlayerItems(player, itemSpecs)
    local inv = safeCall(player, "getInventory")
    if inv == nil or type(itemSpecs) ~= "table" then return {} end
    local given = {}
    for _, spec in ipairs(itemSpecs) do
        local fullType = type(spec) == "table" and (spec.item or spec[1]) or tostring(spec)
        local count = math.max(1, math.floor(tonumber(type(spec) == "table" and (spec.count or spec[2]) or 1) or 1))
        local addedCount = 0
        for _ = 1, count do
            local ok, added = pcall(function() return inv:AddItem(fullType) end)
            if ok and added ~= nil then
                addedCount = addedCount + 1
                pcall(function()
                    if type(sendAddItemToContainer) == "function" and A.side() == "server" then
                        sendAddItemToContainer(inv, added)
                    end
                end)
            end
        end
        if addedCount > 0 then
            given[#given + 1] = { item = fullType, count = addedCount }
        end
    end
    return given
end

return R
