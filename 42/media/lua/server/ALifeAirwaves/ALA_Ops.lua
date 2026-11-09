-- A-Life: Airwaves & Contracts - server operations: SOS acceptance & fulfillment,
-- supply dispatches, caravan routing calls, town recon intel, and state sync.

require "ALifeAirwaves/ALA_Director"

local A = ALifeAirwaves
local D = A.Director

local function P() return ProjectALife end

function D.reply(player, command, args)
    args = type(args) == "table" and args or {}
    args.playerNum = player and type(player.getPlayerNum) == "function" and player:getPlayerNum() or 0
    if A.side() == "server" and player ~= nil then
        pcall(sendServerCommand, player, A.MODULE, command, args)
    elseif A.Client ~= nil and type(A.Client.receive) == "function" then
        pcall(A.Client.receive, A.MODULE, command, args)
    end
end

function D.notifyPlayers(command, args)
    args = type(args) == "table" and args or {}
    if A.side() == "server" then
        pcall(sendServerCommand, A.MODULE, command, args)
    elseif A.Client ~= nil and type(A.Client.receive) == "function" then
        pcall(A.Client.receive, A.MODULE, command, args)
    end
end

function D.countNearbyZombies(x, y, radius)
    radius = tonumber(radius) or 18
    local count = 0
    local cell = type(getCell) == "function" and getCell() or nil
    local list = cell and type(cell.getZombieList) == "function" and cell:getZombieList() or nil
    if list == nil or type(list.size) ~= "function" then return 0 end
    local r2 = radius * radius
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z ~= nil and not (type(z.isDead) == "function" and z:isDead()) then
            local isNpc = false
            pcall(function()
                local md = z:getModData()
                if md and (md.ALifeUID ~= nil or md.ProjectALife == true) then isNpc = true end
            end)
            if not isNpc then
                local zx, zy = A.xyz(z)
                if zx ~= nil then
                    local dx, dy = zx - x, zy - y
                    if dx * dx + dy * dy <= r2 then count = count + 1 end
                end
            end
        end
    end
    return count
end

function D.acceptSOS(player, contractId)
    if not A.authority() or player == nil then return false, "no_authority" end
    local okTx, whyTx = A.RadioCheck.canTransmit(player, false)
    if not okTx then
        D.reply(player, "notice", { key = "err_" .. tostring(whyTx) })
        return false, whyTx
    end
    local c = A.Ledger.getContract(contractId)
    if c == nil or (c.state ~= "open" and c.state ~= "accepted") then
        D.reply(player, "notice", { key = "err_sos_closed" })
        return false, "sos_closed"
    end
    local now = A.now()
    if now >= (tonumber(c.deadlineMs) or 0) then
        c.state = "expired"
        A.metrics.sosFailed = A.metrics.sosFailed + 1
        A.Ledger.touch()
        D.publish(true)
        D.reply(player, "notice", { key = "err_sos_expired" })
        return false, "sos_expired"
    end
    local key = A.playerKey(player)
    if c.owner ~= nil and c.owner ~= key then
        D.reply(player, "notice", { key = "err_sos_taken" })
        return false, "sos_taken"
    end
    c.owner = key
    c.state = "accepted"
    c.acceptedMs = now
    D.materializeSOS(c, player)
    A.metrics.sosAccepted = A.metrics.sosAccepted + 1
    A.Ledger.touch()
    D.publish(true)
    D.reply(player, "sosNotice", { key = "accepted", callsign = c.callsign, town = c.town, x = c.x, y = c.y, id = c.id })
    return true
end

function D.completeSOS(c, player)
    local store = A.Ledger.open()
    if store.receipts[c.id] ~= nil then return false, "already_paid" end
    local key = A.playerKey(player)
    c.state = "completed"
    c.completedMs = A.now()
    c.owner = c.owner or key
    store.receipts[c.id] = { state = "completed", owner = c.owner, atMs = c.completedMs }
    local given = A.RadioCheck.givePlayerItems(player, c.rewards or {})
    local favor = A.Ledger.addFavor(key, c.factionId or "survivors", tonumber(c.favorReward) or 3)
    local rep = P() and P().Reputation
    if rep ~= nil and type(rep.onPlayerHelped) == "function" then
        pcall(rep.onPlayerHelped, player, c.factionId)
    end
    if type(c.actorUids) == "table" and #c.actorUids > 0 then
        local find = P() and (P().Talk and P().Talk.shellFor or P().Speech and P().Speech.findShell)
        if type(find) == "function" then
            local okS, shell = pcall(find, c.actorUids[1])
            if okS and shell then
                A.Lines.say(shell, "sos_resolved", { uid = c.actorUids[1], vars = { callsign = c.callsign, faction = c.factionName } })
            end
        end
    end
    A.metrics.sosCompleted = A.metrics.sosCompleted + 1
    A.Ledger.touch()
    D.publish(true)
    D.reply(player, "sosNotice", {
        key = "completed",
        callsign = c.callsign,
        faction = c.factionName,
        favor = favor,
        items = given,
    })
    return true, given
end

function D.fulfillSOS(player, contractId)
    if not A.authority() or player == nil then return false, "no_authority" end
    local c = A.Ledger.getContract(contractId)
    if c == nil or (c.state ~= "open" and c.state ~= "accepted") then
        D.reply(player, "notice", { key = "err_sos_closed" })
        return false, "sos_closed"
    end
    local px, py = A.xyz(player)
    if px == nil or A.dist(px, py, c.x, c.y) > 28 then
        D.reply(player, "notice", { key = "err_too_far", vars = { x = c.x, y = c.y } })
        return false, "too_far"
    end
    D.materializeSOS(c, player)
    if c.needKind ~= nil then
        if not A.Catalog.consumeNeedItems(player, c.needKind) then
            D.reply(player, "notice", { key = "err_missing_need_" .. tostring(c.needKind) })
            return false, "missing_supplies"
        end
    else
        local zeds = D.countNearbyZombies(c.x, c.y, 16)
        if zeds > 0 then
            D.reply(player, "notice", { key = "err_zombies_remain", vars = { count = zeds } })
            return false, "zombies_remain"
        end
    end
    return D.completeSOS(c, player)
end

function D.tickSOS(now, players)
    for _, c in ipairs(A.Ledger.listContracts(false)) do
        if now >= (tonumber(c.deadlineMs) or 0) then
            c.state = "expired"
            A.metrics.sosFailed = A.metrics.sosFailed + 1
            D.publishDirty = true
            A.Ledger.touch()
        else
            for _, p in ipairs(players) do
                local px, py = A.xyz(p)
                if px ~= nil then
                    local dist = A.dist(px, py, c.x, c.y)
                    if dist <= 85 and not c.materialized then
                        D.materializeSOS(c, p)
                    end
                    if c.state == "accepted" and c.owner == A.playerKey(p) and c.needKind == nil and dist <= 22 then
                        if D.countNearbyZombies(c.x, c.y, 16) == 0 then
                            D.completeSOS(c, p)
                        end
                    end
                end
            end
        end
    end
end

function D.requestDispatch(player, pkgId)
    if not A.authority() or player == nil then return false, "no_authority" end
    local okTx, whyTx = A.RadioCheck.canTransmit(player, true)
    if not okTx then
        D.reply(player, "notice", { key = "err_" .. tostring(whyTx) })
        return false, whyTx
    end
    local pkg = A.Catalog.packageById(pkgId)
    if pkg == nil then return false, "invalid_package" end
    local store = A.Ledger.open()
    local key = A.playerKey(player)
    local now = A.now()
    local cdUntil = tonumber(store.cooldowns.dispatchByPlayer[key]) or 0
    if now < cdUntil then
        local mins = math.max(1, math.ceil((cdUntil - now) / 60000))
        D.reply(player, "notice", { key = "err_dispatch_cooldown", vars = { mins = mins } })
        return false, "cooldown"
    end
    local okPay, whyPay = A.RadioCheck.spendPlayerCredit(player, pkg.cost)
    if not okPay then
        D.reply(player, "notice", { key = "err_insufficient_credit", vars = { cost = pkg.cost } })
        return false, whyPay
    end
    local px, py = A.xyz(player)
    px, py = math.floor(tonumber(px) or 10630), math.floor(tonumber(py) or 9780)
    local angle = (A.rand(360) * math.pi) / 180.0
    local dx = math.floor(px + math.cos(angle) * 28)
    local dy = math.floor(py + math.sin(angle) * 28)
    local townName = A.Catalog.nearestTown(dx, dy)
    local facId, facName, catalog = D.pickFaction()
    local callsign = A.pick(A.Catalog.CALLSIGNS) or "Outrider-9"
    local actorUids = {}
    local p = P()
    if p and p.DebugService and type(p.DebugService.rawSpawn) == "function" then
        local crewIds = D.pickCrewProfiles(catalog, facId, 2)
        if crewIds ~= nil and #crewIds > 0 then
            local okS, res = pcall(p.DebugService.rawSpawn, player, {
                requestId = "ala_drop_" .. tostring(now),
                profileIds = crewIds,
                count = #crewIds,
                factionId = facId,
                x = dx,
                y = dy,
                z = 0,
                mode = "guard",
                radius = 5,
                distance = 0,
                separation = 2,
                arrival = "on_foot",
                encounterId = "ala_supply_drop",
                encounterPersistent = false,
                supportPolicy = "disabled",
                playerKeepOut = 0,
                spawnDelayMs = 0,
            }, true)
            if okS and type(res) == "table" and type(res.uids) == "table" then
                for _, uid in ipairs(res.uids) do actorUids[#actorUids + 1] = uid end
            end
        end
    end
    local dispatch = A.Ledger.putDispatch({
        pkgId = pkg.id,
        owner = key,
        factionId = facId,
        factionName = facName,
        callsign = callsign,
        x = dx,
        y = dy,
        town = townName,
        state = "ready",
        items = A.copy(pkg.items),
        actorUids = actorUids,
        atMs = now,
    })
    store.cooldowns.dispatchByPlayer[key] = now + (tonumber(A.settings.supplyDispatchCooldownMinutes) or 12) * 60000
    local vars = { callsign = callsign, faction = facName, town = townName, x = tostring(dx), y = tostring(dy) }
    local text, lineKey = A.Lines.text("dispatch_ack", vars)
    if text == nil then
        text = "[" .. callsign .. "] Supply drop positioned near " .. townName .. " (" .. dx .. "," .. dy .. ")."
    end
    local day, hour = D.clock()
    local bEntry = A.Ledger.appendBroadcast({
        channel = pkg.channel or "trade",
        freq = A.channelFreq(pkg.channel or "trade"),
        speaker = callsign,
        factionId = facId,
        factionName = facName,
        kind = "dispatch_ack",
        key = lineKey,
        vars = vars,
        text = text,
        x = dx,
        y = dy,
        town = townName,
        day = day,
        hour = hour,
        atMs = now,
        dispatchId = dispatch.id,
    })
    A.ZomboidRadio.air(pkg.channel or "trade", callsign, text, { 0.45, 0.85, 0.78 })
    A.metrics.dispatches = A.metrics.dispatches + 1
    A.metrics.broadcasts = A.metrics.broadcasts + 1
    A.Ledger.touch()
    D.publish(true)
    D.reply(player, "dispatchNotice", { key = "dispatched", dispatch = dispatch, broadcast = bEntry })
    return true, dispatch
end

function D.claimDispatch(player, dispatchId)
    if not A.authority() or player == nil then return false, "no_authority" end
    local d = A.Ledger.getDispatch(dispatchId)
    if d == nil or d.state ~= "ready" then
        D.reply(player, "notice", { key = "err_dispatch_closed" })
        return false, "dispatch_closed"
    end
    local px, py = A.xyz(player)
    if px == nil or A.dist(px, py, d.x, d.y) > 25 then
        D.reply(player, "notice", { key = "err_too_far", vars = { x = d.x, y = d.y } })
        return false, "too_far"
    end
    local store = A.Ledger.open()
    if store.receipts[d.id] ~= nil then return false, "already_claimed" end
    d.state = "claimed"
    d.claimedMs = A.now()
    store.receipts[d.id] = { state = "claimed", owner = A.playerKey(player), atMs = d.claimedMs }
    local given = A.RadioCheck.givePlayerItems(player, d.items or {})
    A.metrics.dispatchClaimed = A.metrics.dispatchClaimed + 1
    A.Ledger.touch()
    D.publish(true)
    D.reply(player, "dispatchNotice", { key = "claimed", callsign = d.callsign, items = given })
    return true, given
end

function D.callCaravan(player)
    if not A.authority() or player == nil then return false, "no_authority" end
    local okTx, whyTx = A.RadioCheck.canTransmit(player, true)
    if not okTx then
        D.reply(player, "notice", { key = "err_" .. tostring(whyTx) })
        return false, whyTx
    end
    local px, py = A.xyz(player)
    px, py = tonumber(px) or 10630, tonumber(py) or 9780
    if ALifeCaravans and ALifeCaravans.Ledger and type(ALifeCaravans.Ledger.list) == "function" then
        local best, bestD = nil, math.huge
        for _, c in ipairs(ALifeCaravans.Ledger.list()) do
            if not c.hostile and c.state ~= "defeated" and tonumber(c.x) and tonumber(c.y) then
                local d = A.dist(px, py, c.x, c.y)
                if d < bestD then best, bestD = c, d end
            end
        end
        if best ~= nil then
            if best.state == "rendered" and ALifeCaravans.Director and type(ALifeCaravans.Director.halt) == "function" and bestD <= 180 then
                pcall(ALifeCaravans.Director.halt, best, 180, "hail")
            end
            local cx, cy = math.floor(best.x), math.floor(best.y)
            local town = A.Catalog.nearestTown(cx, cy)
            local vars = {
                callsign = tostring(best.callsign or best.name or "Convoy"),
                faction = tostring(best.factionName or best.name or "Traders"),
                town = town,
                dest = tostring(best.destName or town),
                x = tostring(cx),
                y = tostring(cy),
            }
            local text, lineKey = A.Lines.text("air_caravan", vars)
            if text == nil then
                text = "[" .. vars.callsign .. "] Convoy at " .. town .. " (" .. cx .. "," .. cy .. ") en route to " .. vars.dest
            end
            local day, hour = D.clock()
            local bEntry = A.Ledger.appendBroadcast({
                channel = "trade",
                freq = A.channelFreq("trade"),
                speaker = vars.callsign,
                factionId = best.factionId,
                factionName = vars.faction,
                kind = "air_caravan",
                key = lineKey,
                vars = vars,
                text = text,
                x = cx,
                y = cy,
                town = town,
                day = day,
                hour = hour,
                atMs = A.now(),
            })
            A.ZomboidRadio.air("trade", vars.callsign, text, { 0.95, 0.76, 0.32 })
            A.metrics.caravanCalls = A.metrics.caravanCalls + 1
            A.metrics.broadcasts = A.metrics.broadcasts + 1
            D.publish(true)
            D.reply(player, "dispatchNotice", { key = "caravan_called", broadcast = bEntry, x = cx, y = cy, callsign = vars.callsign })
            return true, best
        end
    end
    return D.requestDispatch(player, "pkg_rations")
end

function D.requestIntel(player, townId)
    if not A.authority() or player == nil then return false, "no_authority" end
    local okTx, whyTx = A.RadioCheck.canTransmit(player, true)
    if not okTx then
        D.reply(player, "notice", { key = "err_" .. tostring(whyTx) })
        return false, whyTx
    end
    local store = A.Ledger.open()
    local key = A.playerKey(player)
    local now = A.now()
    local cdUntil = tonumber(store.cooldowns.intelByPlayer[key]) or 0
    if now < cdUntil then
        local mins = math.max(1, math.ceil((cdUntil - now) / 60000))
        D.reply(player, "notice", { key = "err_intel_cooldown", vars = { mins = mins } })
        return false, "cooldown"
    end
    local town = nil
    for _, t in ipairs(A.Catalog.TOWNS) do
        if t.id == townId or t.name == townId then town = t break end
    end
    town = town or A.Catalog.TOWNS[1]
    local okPay, whyPay = A.RadioCheck.spendPlayerCredit(player, 35)
    if not okPay then
        D.reply(player, "notice", { key = "err_insufficient_credit", vars = { cost = 35 } })
        return false, whyPay
    end
    local facts = D.gatherWorldFacts()
    local squads, outposts, caravans = 0, 0, 0
    for _, f in ipairs(facts) do
        if A.dist(town.x, town.y, f.x or 0, f.y or 0) <= 900 then
            if f.source == "caravan" then caravans = caravans + 1
            elseif f.source == "outpost" then outposts = outposts + 1
            else squads = squads + 1 end
        end
    end
    local zeds = D.countNearbyZombies(town.x, town.y, 120)
    local danger = zeds >= 20 and "high" or (zeds >= 6 and "medium" or "low")
    local report = {
        townId = town.id,
        townName = town.name,
        x = town.x,
        y = town.y,
        squads = squads,
        outposts = outposts,
        caravans = caravans,
        zombies = zeds,
        danger = danger,
        atMs = now,
    }
    store.intel[town.id] = report
    store.cooldowns.intelByPlayer[key] = now + (tonumber(A.settings.intelCooldownMinutes) or 5) * 60000
    local vars = {
        town = town.name,
        squads = tostring(squads),
        outposts = tostring(outposts),
        caravans = tostring(caravans),
        danger = string.upper(danger),
        x = tostring(town.x),
        y = tostring(town.y),
    }
    local text, lineKey = A.Lines.text("intel_report", vars)
    if text == nil then
        text = "[RECON] " .. town.name .. ": squads=" .. squads .. ", outposts=" .. outposts .. ", convoys=" .. caravans .. ", threat=" .. vars.danger
    end
    local day, hour = D.clock()
    local bEntry = A.Ledger.appendBroadcast({
        channel = "tactical",
        freq = A.channelFreq("tactical"),
        speaker = "Recon-HQ",
        factionId = "recon",
        factionName = "Recon Network",
        kind = "intel_report",
        key = lineKey,
        vars = vars,
        text = text,
        x = town.x,
        y = town.y,
        town = town.name,
        day = day,
        hour = hour,
        atMs = now,
    })
    A.ZomboidRadio.air("tactical", "Recon-HQ", text, { 0.55, 0.78, 0.96 })
    A.metrics.intelReports = A.metrics.intelReports + 1
    A.metrics.broadcasts = A.metrics.broadcasts + 1
    A.Ledger.touch()
    D.publish(true)
    D.reply(player, "intelNotice", { report = report, broadcast = bEntry })
    return true, report
end

function D.statePayload()
    local store = A.Ledger.open()
    return {
        log = A.Ledger.listBroadcasts(),
        contracts = A.Ledger.listContracts(false),
        dispatches = A.Ledger.listDispatches(false),
        intel = store.intel,
        favor = store.favor,
        caravansActive = (ALifeCaravans and ALifeCaravans.Ledger ~= nil) == true,
    }
end

function D.publish(force)
    local now = A.now()
    if not force and not D.publishDirty and now < D.publishAtMs then return end
    D.publishAtMs = now + 4000
    D.publishDirty = false
    local payload = D.statePayload()
    D.notifyPlayers("state", payload)
end

function D.sendState(player)
    D.reply(player, "state", D.statePayload())
end

function D.command(player, command, args)
    args = type(args) == "table" and args or {}
    if command == "stateRequest" then
        D.sendState(player)
        return true
    elseif command == "tuneRadio" then
        local ok, freq, devName = A.RadioCheck.tunePlayerRadio(player, args.freq)
        if ok then
            D.reply(player, "notice", { key = "tuned", vars = { freq = A.freqMhz(freq), device = devName } })
        else
            D.reply(player, "notice", { key = "err_no_radio" })
        end
        return ok
    elseif command == "scanAirwaves" then
        local okRx, whyRx = A.RadioCheck.canReceive(player)
        if not okRx then
            D.reply(player, "notice", { key = "err_" .. tostring(whyRx) })
            return false, whyRx
        end
        local b = D.emitBroadcast(A.now(), args.kind)
        return true, b
    elseif command == "acceptSOS" then
        return D.acceptSOS(player, args.id)
    elseif command == "fulfillSOS" then
        return D.fulfillSOS(player, args.id)
    elseif command == "requestDispatch" then
        return D.requestDispatch(player, args.pkgId)
    elseif command == "claimDispatch" then
        return D.claimDispatch(player, args.id)
    elseif command == "callCaravan" then
        return D.callCaravan(player)
    elseif command == "requestIntel" then
        return D.requestIntel(player, args.townId)
    end
    return false, "unknown_command"
end

function D.tick()
    if not A.authority() or not A.settings.enabled then return end
    local now = A.now()
    if now < D.nextTickMs then return end
    D.nextTickMs = now + D.intervalMs
    local store = A.Ledger.open()
    local players = A.players()
    if now >= (tonumber(store.cooldowns.nextBroadcastMs) or 0) then
        local intervalMs = (tonumber(A.settings.broadcastIntervalMinutes) or 4) * 60000
        store.cooldowns.nextBroadcastMs = now + math.floor(intervalMs * (0.8 + A.randFloat() * 0.4))
        D.emitBroadcast(now)
    end
    local openContracts = A.Ledger.listContracts(false)
    if #openContracts < 4 and now >= (tonumber(store.cooldowns.nextSOSMs) or 0) then
        local intervalMs = (tonumber(A.settings.sosContractIntervalMinutes) or 8) * 60000
        store.cooldowns.nextSOSMs = now + math.floor(intervalMs * (0.8 + A.randFloat() * 0.4))
        D.createSOS(now, nil, players[1])
    end
    D.tickSOS(now, players)
    D.publish(false)
end

function D.describe()
    local lines = {}
    local contracts = A.Ledger.listContracts(false)
    local dispatches = A.Ledger.listDispatches(false)
    lines[#lines + 1] = string.format("broadcastLog=%d activeSOS=%d activeDispatches=%d",
        #A.Ledger.listBroadcasts(), #contracts, #dispatches)
    for _, c in ipairs(contracts) do
        lines[#lines + 1] = string.format("SOS %s [%s] %s (%s) at %d,%d state=%s owner=%s",
            tostring(c.id), tostring(c.kind), tostring(c.callsign), tostring(c.town),
            math.floor(c.x or 0), math.floor(c.y or 0), tostring(c.state), tostring(c.owner or "none"))
    end
    return lines
end

return D
