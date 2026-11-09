-- A-Life: Airwaves & Contracts - persistent ledger (server / singleplayer).
-- Stored in ProjectALife.Persistence.bucket("ala_airwaves") with ModData fallback.

require "ALifeAirwaves/00_ALA_Core"

local A = ALifeAirwaves
local Ledger = { store = nil, fallback = false }
A.Ledger = Ledger

local DEFAULTS = {
    schema = A.SCHEMA,
    sequence = 0,
    log = {},
    contracts = {},
    dispatches = {},
    intel = {},
    favor = {},
    cooldowns = {
        nextBroadcastMs = 0,
        nextSOSMs = 0,
        dispatchByPlayer = {},
        intelByPlayer = {},
    },
    receipts = {},
}

function Ledger.open()
    if Ledger.store ~= nil then return Ledger.store end
    local persistence = ProjectALife and ProjectALife.Persistence
    local store
    Ledger.fallback = false
    if persistence ~= nil and type(persistence.bucket) == "function" then
        local ok, bucket = pcall(persistence.bucket, "ala_airwaves", A.copy(DEFAULTS))
        if ok and type(bucket) == "table" then store = bucket else A.fail("ledger bucket", bucket) end
    end
    if store == nil then
        if type(ModData) == "table" and type(ModData.getOrCreate) == "function" then
            local ok, data = pcall(ModData.getOrCreate, "ALifeAirwaves.v1")
            if ok and type(data) == "table" then store = data end
        end
        store = store or {}
        Ledger.fallback = true
    end
    for key, value in pairs(DEFAULTS) do
        if store[key] == nil then store[key] = A.copy(value) end
    end
    store.log = type(store.log) == "table" and store.log or {}
    store.contracts = type(store.contracts) == "table" and store.contracts or {}
    store.dispatches = type(store.dispatches) == "table" and store.dispatches or {}
    store.intel = type(store.intel) == "table" and store.intel or {}
    store.favor = type(store.favor) == "table" and store.favor or {}
    store.cooldowns = type(store.cooldowns) == "table" and store.cooldowns or A.copy(DEFAULTS.cooldowns)
    store.cooldowns.dispatchByPlayer = type(store.cooldowns.dispatchByPlayer) == "table" and store.cooldowns.dispatchByPlayer or {}
    store.cooldowns.intelByPlayer = type(store.cooldowns.intelByPlayer) == "table" and store.cooldowns.intelByPlayer or {}
    store.receipts = type(store.receipts) == "table" and store.receipts or {}
    Ledger.store = store
    return store
end

function Ledger.touch()
    local persistence = ProjectALife and ProjectALife.Persistence
    if not Ledger.fallback and persistence ~= nil and type(persistence.touch) == "function" then
        pcall(persistence.touch)
    elseif Ledger.fallback and type(ModData) == "table" and type(ModData.transmit) == "function" then
        pcall(ModData.transmit, "ALifeAirwaves.v1")
    end
end

function Ledger.nextId(prefix)
    local store = Ledger.open()
    store.sequence = (tonumber(store.sequence) or 0) + 1
    Ledger.touch()
    return tostring(prefix or "ala") .. ":" .. tostring(store.sequence)
end

function Ledger.appendBroadcast(entry)
    local store = Ledger.open()
    entry.id = entry.id or Ledger.nextId("air")
    store.log[#store.log + 1] = entry
    while #store.log > 50 do
        table.remove(store.log, 1)
    end
    Ledger.touch()
    return entry
end

function Ledger.listBroadcasts()
    local store = Ledger.open()
    local out = {}
    for i = #store.log, 1, -1 do
        out[#out + 1] = store.log[i]
    end
    return out
end

function Ledger.putContract(contract)
    local store = Ledger.open()
    contract.id = contract.id or Ledger.nextId("sos")
    store.contracts[contract.id] = contract
    Ledger.touch()
    return contract
end

function Ledger.getContract(id)
    if id == nil then return nil end
    return Ledger.open().contracts[tostring(id)]
end

function Ledger.listContracts(includeClosed)
    local store = Ledger.open()
    local out = {}
    for _, c in pairs(store.contracts) do
        if includeClosed or (c.state == "open" or c.state == "accepted" or c.state == "active") then
            out[#out + 1] = c
        end
    end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

function Ledger.putDispatch(dispatch)
    local store = Ledger.open()
    dispatch.id = dispatch.id or Ledger.nextId("drop")
    store.dispatches[dispatch.id] = dispatch
    Ledger.touch()
    return dispatch
end

function Ledger.getDispatch(id)
    if id == nil then return nil end
    return Ledger.open().dispatches[tostring(id)]
end

function Ledger.listDispatches(includeClosed)
    local store = Ledger.open()
    local out = {}
    for _, d in pairs(store.dispatches) do
        if includeClosed or (d.state == "enroute" or d.state == "ready") then
            out[#out + 1] = d
        end
    end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

function Ledger.addFavor(playerKey, factionId, delta)
    if type(playerKey) ~= "string" or type(factionId) ~= "string" then return 0 end
    local store = Ledger.open()
    store.favor[playerKey] = store.favor[playerKey] or {}
    local cur = tonumber(store.favor[playerKey][factionId]) or 0
    local nextVal = A.clamp(cur + (tonumber(delta) or 0), -10, 20, cur)
    store.favor[playerKey][factionId] = nextVal
    if ALifeCaravans and ALifeCaravans.Ledger and type(ALifeCaravans.Ledger.addFavor) == "function" then
        pcall(ALifeCaravans.Ledger.addFavor, playerKey, factionId, delta)
    end
    Ledger.touch()
    return nextVal
end

function Ledger.favor(playerKey, factionId)
    local store = Ledger.open()
    local row = store.favor[tostring(playerKey)]
    return tonumber(row and row[tostring(factionId)]) or 0
end

return Ledger
