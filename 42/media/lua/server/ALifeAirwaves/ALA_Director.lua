-- A-Life: Airwaves & Contracts - server / singleplayer director.
-- Generates live survivor & caravan broadcasts from Project A-Life world state,
-- manages dynamic SOS beacons & field contracts, handles supply dispatches &
-- caravan calls, and compiles town recon intelligence.

require "ALifeAirwaves/00_ALA_Core"
require "ALifeAirwaves/01_ALA_Lines"
require "ALifeAirwaves/02_ALA_RadioCheck"
require "ALifeAirwaves/03_ALA_Catalog"
require "ALifeAirwaves/ALA_Ledger"
require "ALifeAirwaves/ALA_ZomboidRadio"

local A = ALifeAirwaves
local D = {
    nextTickMs = 0,
    intervalMs = 2000,
    publishAtMs = 0,
    publishDirty = false,
}
A.Director = D

local function P() return ProjectALife end

function D.clock()
    local rules = P() and P().FactionSpawnRules
    if rules ~= nil and type(rules.clock) == "function" then
        local ok, day, hour = pcall(rules.clock)
        if ok and type(day) == "number" then return day, math.floor(tonumber(hour) or 12) end
    end
    local day, hour = 1, 12
    pcall(function()
        local gt = getGameTime()
        day = math.floor(gt:getNightsSurvived()) + 1
        hour = math.floor(gt:getTimeOfDay())
    end)
    return day, hour
end

function D.pickFaction()
    local p = P()
    local catalog = p and p.Catalog and (p.Catalog.current or (type(p.Catalog.load) == "function" and p.Catalog.load())) or nil
    if catalog ~= nil and type(catalog.factionOrder) == "table" and #catalog.factionOrder > 0 then
        local friendly = {}
        local rules = p.FactionSpawnRules
        for _, fac in ipairs(catalog.factionOrder) do
            if type(fac) == "table" and (not fac.general or not fac.general.deleted) then
                local hostile = rules and type(rules.hostile) == "function" and rules.hostile(fac) == true
                if not hostile then friendly[#friendly + 1] = fac end
            end
        end
        local chosen = A.pick(#friendly > 0 and friendly or catalog.factionOrder)
        if chosen ~= nil then
            local name = tostring(chosen.general and chosen.general.name or chosen.id)
            return chosen.id, name, catalog
        end
    end
    return "survivors", "Knox Survivors", nil
end

function D.pickCrewProfiles(catalog, factionId, count)
    count = math.max(1, math.min(4, tonumber(count) or 2))
    local roster = {}
    for _, prof in ipairs(catalog and catalog.npcOrder or {}) do
        if prof.general and prof.general.faction == factionId and not prof.general.deleted then
            roster[#roster + 1] = prof
        end
    end
    if #roster == 0 then return nil, "Survivor" end
    local ids = {}
    local leaderName = tostring(roster[1].general and roster[1].general.name or "Survivor")
    for i = 1, count do
        local pick = roster[((i - 1) % #roster) + 1]
        ids[#ids + 1] = pick.id
        if i == 1 and pick.general and pick.general.name then leaderName = tostring(pick.general.name) end
    end
    return ids, leaderName
end

function D.gatherWorldFacts()
    local facts = {}
    local p = P()
    pcall(function()
        local ledger = p and p.SquadLedger
        if ledger == nil then return end
        local function visit(squad)
            if type(squad) == "table" and tonumber(squad.x) and tonumber(squad.y) and squad.state ~= "wiped" then
                local facId = tostring(squad.factionId or "survivors")
                local facName = facId
                if p.Catalog and type(p.Catalog.faction) == "function" then
                    local ok, f = pcall(p.Catalog.faction, facId)
                    if ok and f and f.general and f.general.name then facName = tostring(f.general.name) end
                end
                facts[#facts + 1] = {
                    source = "squad",
                    factionId = facId,
                    faction = facName,
                    x = math.floor(tonumber(squad.x)),
                    y = math.floor(tonumber(squad.y)),
                    town = A.Catalog.nearestTown(squad.x, squad.y),
                    count = type(squad.members) == "table" and #squad.members or (tonumber(squad.size) or 3),
                }
            end
        end
        if type(ledger.eachLive) == "function" then ledger.eachLive(visit)
        elseif type(ledger.list) == "function" then
            for _, sq in ipairs(ledger.list()) do visit(sq) end
        end
    end)
    pcall(function()
        local sites = p and p.OutpostRegistry
        if sites ~= nil and type(sites.list) == "function" then
            for _, site in ipairs(sites.list()) do
                if tonumber(site.x) and tonumber(site.y) then
                    local facId = tostring(site.factionId or "survivors")
                    local facName = facId
                    if p.Catalog and type(p.Catalog.faction) == "function" then
                        local ok, f = pcall(p.Catalog.faction, facId)
                        if ok and f and f.general and f.general.name then facName = tostring(f.general.name) end
                    end
                    facts[#facts + 1] = {
                        source = "outpost",
                        factionId = facId,
                        faction = facName,
                        x = math.floor(tonumber(site.x)),
                        y = math.floor(tonumber(site.y)),
                        town = A.Catalog.nearestTown(site.x, site.y),
                        count = 4,
                    }
                end
            end
        end
    end)
    pcall(function()
        if ALifeCaravans and ALifeCaravans.Ledger and type(ALifeCaravans.Ledger.list) == "function" then
            for _, c in ipairs(ALifeCaravans.Ledger.list()) do
                if tonumber(c.x) and tonumber(c.y) and c.state ~= "defeated" then
                    facts[#facts + 1] = {
                        source = "caravan",
                        caravanId = c.id,
                        factionId = tostring(c.factionId or "traders"),
                        faction = tostring(c.factionName or c.name or "Caravan"),
                        callsign = tostring(c.callsign or "Convoy"),
                        dest = tostring(c.destName or "Muldraugh"),
                        x = math.floor(tonumber(c.x)),
                        y = math.floor(tonumber(c.y)),
                        town = A.Catalog.nearestTown(c.x, c.y),
                        count = type(c.crew) == "table" and #c.crew or 4,
                    }
                end
            end
        end
    end)
    if #facts == 0 then
        local town = A.pick(A.Catalog.TOWNS) or A.Catalog.TOWNS[1]
        local facId, facName = D.pickFaction()
        facts[1] = {
            source = "patrol",
            factionId = facId,
            faction = facName,
            x = town.x + A.rand(120) - 60,
            y = town.y + A.rand(120) - 60,
            town = town.name,
            count = 3,
        }
    end
    return facts
end

function D.emitBroadcast(now, forcedSituation)
    now = now or A.now()
    local facts = D.gatherWorldFacts()
    local fact = A.pick(facts)
    local callsign = fact.callsign or A.pick(A.Catalog.CALLSIGNS) or "Sierra-1"
    local situation = forcedSituation
    local channel = "emergency"
    if situation == nil then
        if fact.source == "caravan" then
            situation = "air_caravan"
            channel = "trade"
        elseif fact.source == "outpost" then
            situation = "air_camp"
            channel = "trade"
        else
            local roll = A.rand(3)
            if roll == 0 then situation, channel = "air_sighting", "emergency"
            elseif roll == 1 then situation, channel = "air_horde", "emergency"
            else situation, channel = "air_skirmish", "tactical" end
        end
    elseif situation == "air_caravan" or situation == "air_camp" then
        channel = "trade"
    elseif situation == "air_skirmish" then
        channel = "tactical"
    end

    local vars = {
        callsign = tostring(callsign),
        faction = tostring(fact.faction or "Survivors"),
        town = tostring(fact.town or "Muldraugh"),
        x = tostring(fact.x or 10630),
        y = tostring(fact.y or 9780),
        dest = tostring(fact.dest or fact.town or "West Point"),
        count = tostring(fact.count or 3),
    }
    local text, key = A.Lines.text(situation, vars)
    if text == nil then
        text = "[" .. vars.callsign .. "] " .. vars.faction .. " near " .. vars.town .. " (" .. vars.x .. "," .. vars.y .. ")"
    end
    local day, hour = D.clock()
    local freq = A.channelFreq(channel)
    local entry = A.Ledger.appendBroadcast({
        channel = channel,
        freq = freq,
        speaker = callsign,
        factionId = fact.factionId,
        factionName = vars.faction,
        kind = situation,
        key = key,
        vars = vars,
        text = text,
        x = tonumber(fact.x) or 10630,
        y = tonumber(fact.y) or 9780,
        town = vars.town,
        day = day,
        hour = hour,
        atMs = now,
    })
    A.ZomboidRadio.air(channel, callsign, text, { 0.78, 0.92, 0.84 })
    A.metrics.broadcasts = A.metrics.broadcasts + 1
    D.publishDirty = true
    if type(D.publish) == "function" then D.publish(true) end
    D.notifyPlayers("broadcast", { entry = entry })
    return entry
end

function D.materializeSOS(contract, player)
    if contract == nil or contract.materialized == true then return true end
    local p = P()
    local px, py = A.xyz(player)
    if px == nil or A.dist(px, py, contract.x, contract.y) > 110 then return false end
    contract.materialized = true
    contract.actorUids = contract.actorUids or {}
    local facId, _, catalog = D.pickFaction()
    contract.factionId = contract.factionId or facId
    if p and p.DebugService and type(p.DebugService.rawSpawn) == "function" then
        local crewIds = D.pickCrewProfiles(catalog, contract.factionId, 2)
        if crewIds ~= nil and #crewIds > 0 then
            local reqId = "ala_sos_" .. tostring(contract.id)
            local ok, res = pcall(p.DebugService.rawSpawn, player, {
                requestId = reqId,
                profileIds = crewIds,
                count = #crewIds,
                factionId = contract.factionId,
                x = contract.x,
                y = contract.y,
                z = 0,
                mode = "guard",
                radius = 6,
                distance = 0,
                separation = 2,
                arrival = "on_foot",
                encounterId = "ala_sos",
                encounterPersistent = false,
                supportPolicy = "disabled",
                playerKeepOut = 0,
                spawnDelayMs = 0,
            }, true)
            if ok and type(res) == "table" and type(res.uids) == "table" then
                for _, uid in ipairs(res.uids) do contract.actorUids[#contract.actorUids + 1] = uid end
            end
        end
    end
    local spec = A.Catalog.sosSpec(contract.kind)
    local zCount = tonumber(spec and spec.zombieCount) or 0
    if zCount > 0 and type(addZombiesInOutfit) == "function" then
        pcall(addZombiesInOutfit, math.floor(contract.x + 8), math.floor(contract.y + 8), 0, zCount, nil, nil)
    end
    A.Ledger.touch()
    return true
end

function D.createSOS(now, forcedKind, anchorPlayer)
    now = now or A.now()
    local spec = forcedKind and A.Catalog.sosSpec(forcedKind) or A.pick(A.Catalog.SOS_TYPES)
    local facId, facName, catalog = D.pickFaction()
    local _, leaderName = D.pickCrewProfiles(catalog, facId, 2)
    local callsign = A.pick(A.Catalog.CALLSIGNS) or "Beacon-8"
    local tx, ty
    local p0 = anchorPlayer or A.players()[1]
    local px, py = A.xyz(p0)
    if px ~= nil then
        local angle = (A.rand(360) * math.pi) / 180.0
        local dist = 55 + A.rand(65)
        tx = math.floor(px + math.cos(angle) * dist)
        ty = math.floor(py + math.sin(angle) * dist)
    else
        local town = A.pick(A.Catalog.TOWNS) or A.Catalog.TOWNS[1]
        tx = town.x + A.rand(80) - 40
        ty = town.y + A.rand(80) - 40
    end
    local townName = A.Catalog.nearestTown(tx, ty)
    local vars = {
        callsign = callsign,
        leader = leaderName,
        faction = facName,
        town = townName,
        x = tostring(tx),
        y = tostring(ty),
    }
    local text, key = A.Lines.text(spec.lineKey, vars)
    if text == nil then
        text = "SOS [" .. callsign .. "] " .. facName .. " at " .. townName .. " (" .. tx .. "," .. ty .. ")"
    end
    local timeoutMs = (tonumber(A.settings.sosTimeoutMinutes) or 15) * 60000
    local contract = A.Ledger.putContract({
        kind = spec.kind,
        state = "open",
        channel = spec.channel,
        freq = A.channelFreq(spec.channel),
        factionId = facId,
        factionName = facName,
        leaderName = leaderName,
        callsign = callsign,
        x = tx,
        y = ty,
        town = townName,
        needKind = spec.needKind,
        favorReward = spec.favor,
        rewards = A.Catalog.scaledRewards(spec.rewards),
        text = text,
        startedMs = now,
        deadlineMs = now + timeoutMs,
        owner = nil,
        actorUids = {},
    })
    local day, hour = D.clock()
    local bEntry = A.Ledger.appendBroadcast({
        channel = spec.channel,
        freq = contract.freq,
        speaker = "SOS " .. callsign,
        factionId = facId,
        factionName = facName,
        kind = spec.lineKey,
        key = key,
        vars = vars,
        text = text,
        x = tx,
        y = ty,
        town = townName,
        day = day,
        hour = hour,
        atMs = now,
        sosId = contract.id,
    })
    A.ZomboidRadio.air(spec.channel, "SOS " .. callsign, text, { 0.95, 0.38, 0.34 })
    A.metrics.sosCreated = A.metrics.sosCreated + 1
    A.metrics.broadcasts = A.metrics.broadcasts + 1
    D.publishDirty = true
    if type(D.publish) == "function" then D.publish(true) end
    D.notifyPlayers("sosCreated", { contract = contract, broadcast = bEntry })
    return contract
end

return D
