-- A-Life: Airwaves & Contracts - catalog of SOS contracts, supply dispatch
-- packages, SOS need pools, and Knox County towns for recon intel.

require "ALifeAirwaves/00_ALA_Core"
require "ALifeAirwaves/02_ALA_RadioCheck"

local A = ALifeAirwaves
local C = {}
A.Catalog = C

C.CALLSIGNS = {
    "Sierra-1", "Watchtower-3", "Foxtrot-7", "Nomad-2", "Echo-4", "Ranger-6",
    "Vanguard-5", "Outrider-9", "Beacon-8", "Kilo-2", "Raven-4", "Sentinel-1",
}

C.TOWNS = {
    { id = "Muldraugh", name = "Muldraugh", x = 10630, y = 9780 },
    { id = "WestPoint", name = "West Point", x = 11900, y = 6900 },
    { id = "Rosewood", name = "Rosewood", x = 8090, y = 11580 },
    { id = "MarchRidge", name = "March Ridge", x = 10030, y = 12720 },
    { id = "Riverside", name = "Riverside", x = 6350, y = 5330 },
    { id = "EchoCreek", name = "Echo Creek", x = 3580, y = 10910 },
    { id = "Irvington", name = "Irvington", x = 2550, y = 14350 },
    { id = "Brandenburg", name = "Brandenburg", x = 2050, y = 6200 },
    { id = "Louisville", name = "Louisville Checkpoint", x = 12550, y = 4150 },
}

-- Items accepted to fulfill an SOS supply need (`medical`, `ammo`, `breakdown`).
C.SOS_NEEDS = {
    medical = {
        requiredCount = 2,
        items = {
            ["Base.Bandage"] = 1, ["Base.AlcoholBandage"] = 2, ["Base.FirstAidKit"] = 2,
            ["Base.Antibiotics"] = 2, ["Base.Disinfectant"] = 2, ["Base.Pills"] = 1,
            ["Base.SutureNeedle"] = 2, ["Base.Splint"] = 1,
        },
    },
    ammo = {
        requiredCount = 1,
        items = {
            ["Base.Bullets9mmBox"] = 2, ["Base.Bullets45Box"] = 2, ["Base.Bullets38Box"] = 2,
            ["Base.ShotgunShellsBox"] = 2, ["Base.556Box"] = 2, ["Base.308Box"] = 2,
            ["Base.223Box"] = 2, ["Base.Bullets9mm"] = 1, ["Base.ShotgunShells"] = 1,
        },
    },
    breakdown = {
        requiredCount = 1,
        items = {
            ["Base.PetrolCan"] = 2, ["Base.Wrench"] = 2, ["Base.DuctTape"] = 1,
            ["Base.Screwdriver"] = 1, ["Base.CarBattery1"] = 2, ["Base.CarBattery2"] = 2,
            ["Base.CarBattery3"] = 2, ["Base.TirePump"] = 1,
        },
    },
}

C.SOS_TYPES = {
    {
        kind = "horde",
        channel = "emergency",
        lineKey = "sos_horde",
        needKind = nil,
        zombieCount = 4,
        favor = 3,
        rewards = {
            { "Base.Bullets9mmBox", 2 },
            { "Base.FirstAidKit", 1 },
            { "Base.MRE", 2 },
        },
    },
    {
        kind = "medical",
        channel = "emergency",
        lineKey = "sos_medical",
        needKind = "medical",
        zombieCount = 2,
        favor = 3,
        rewards = {
            { "Base.ShotgunShellsBox", 2 },
            { "Base.PetrolCan", 1 },
            { "Base.Money", 5 },
        },
    },
    {
        kind = "ammo",
        channel = "tactical",
        lineKey = "sos_ammo",
        needKind = "ammo",
        zombieCount = 3,
        favor = 4,
        rewards = {
            { "Base.Antibiotics", 1 },
            { "Base.FirstAidKit", 1 },
            { "Base.MRE", 3 },
            { "Base.Money", 6 },
        },
    },
    {
        kind = "breakdown",
        channel = "trade",
        lineKey = "sos_breakdown",
        needKind = "breakdown",
        zombieCount = 2,
        favor = 3,
        rewards = {
            { "Base.556Box", 1 },
            { "Base.Bullets9mmBox", 1 },
            { "Base.CannedCornedBeef", 2 },
            { "Base.Money", 5 },
        },
    },
}

C.PACKAGES = {
    {
        id = "pkg_medical",
        cost = 80,
        channel = "trade",
        items = {
            { "Base.FirstAidKit", 1 },
            { "Base.Antibiotics", 1 },
            { "Base.Bandage", 4 },
            { "Base.Disinfectant", 1 },
            { "Base.Pills", 2 },
        },
    },
    {
        id = "pkg_ammo",
        cost = 110,
        channel = "tactical",
        items = {
            { "Base.Bullets9mmBox", 2 },
            { "Base.ShotgunShellsBox", 2 },
            { "Base.556Box", 1 },
        },
    },
    {
        id = "pkg_fuel",
        cost = 85,
        channel = "trade",
        items = {
            { "Base.PetrolCan", 2 },
            { "Base.Wrench", 1 },
            { "Base.DuctTape", 2 },
        },
    },
    {
        id = "pkg_tools",
        cost = 90,
        channel = "trade",
        items = {
            { "Base.Crowbar", 1 },
            { "Base.Hammer", 1 },
            { "Base.Saw", 1 },
            { "Base.Screwdriver", 1 },
            { "Base.Nails", 2 },
        },
    },
    {
        id = "pkg_rations",
        cost = 65,
        channel = "trade",
        items = {
            { "Base.MRE", 3 },
            { "Base.TinnedBeans", 2 },
            { "Base.CannedCornedBeef", 2 },
            { "Base.WaterBottleFull", 2 },
        },
    },
}

function C.packageById(pkgId)
    for _, pkg in ipairs(C.PACKAGES) do
        if pkg.id == pkgId then return pkg end
    end
    return nil
end

function C.sosSpec(kind)
    for _, spec in ipairs(C.SOS_TYPES) do
        if spec.kind == kind then return spec end
    end
    return C.SOS_TYPES[1]
end

function C.scaledRewards(baseRewards)
    local mult = (tonumber(A.settings.rewardMultiplier) or 100) / 100.0
    local out = {}
    for _, row in ipairs(baseRewards or {}) do
        local item = row[1] or row.item
        local baseCount = tonumber(row[2] or row.count) or 1
        local count = math.max(1, math.floor(baseCount * mult + 0.5))
        out[#out + 1] = { item = item, count = count }
    end
    return out
end

function C.hasNeedItems(player, needKind)
    local spec = C.SOS_NEEDS[tostring(needKind)]
    if spec == nil then return true, {} end
    local inv = player and type(player.getInventory) == "function" and player:getInventory() or nil
    local items = inv and type(inv.getItems) == "function" and inv:getItems() or nil
    if items == nil or type(items.size) ~= "function" then return false, {} end
    local score = 0
    local matched = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item ~= nil and not (type(item.isFavorite) == "function" and item:isFavorite())
                and not (type(player.isEquipped) == "function" and player:isEquipped(item)) then
            local ft = A.RadioCheck.itemFullType(item)
            local pts = spec.items[ft]
            if pts ~= nil then
                score = score + pts
                matched[#matched + 1] = item
                if score >= spec.requiredCount then return true, matched end
            end
        end
    end
    return false, matched
end

function C.consumeNeedItems(player, needKind)
    local ok, matched = C.hasNeedItems(player, needKind)
    if not ok then return false end
    local inv = player and player:getInventory() or nil
    if inv == nil then return false end
    for _, item in ipairs(matched) do
        pcall(function()
            inv:Remove(item)
            if type(sendRemoveItemFromContainer) == "function" and A.side() == "server" then
                sendRemoveItemFromContainer(inv, item)
            end
        end)
    end
    return true
end

function C.nearestTown(x, y)
    local p = ProjectALife
    if p and p.Speech and type(p.Speech.nearestTown) == "function" then
        local ok, name = pcall(p.Speech.nearestTown, x or 0, y or 0)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if p and p.TownRegions and type(p.TownRegions.distanceToTown) == "function" then
        local ok, _, town = pcall(p.TownRegions.distanceToTown, { x = tonumber(x) or 0, y = tonumber(y) or 0 })
        if ok and town and town.label then return tostring(town.label) end
    end
    local best, bestD = "Muldraugh", math.huge
    for _, t in ipairs(C.TOWNS) do
        local d = A.dist(x or 0, y or 0, t.x, t.y)
        if d < bestD then best, bestD = t.name, d end
    end
    return best
end

return C
