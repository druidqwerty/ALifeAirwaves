-- End-to-end live in-game SP verification for A-Life: Airwaves & Contracts (ALifeAirwaves)
-- with ProjectALifeNPCs and ALifeCaravans loaded together in Project Zomboid 42.21.0.
ALALive = ALALive or { once = {} }
local T = { phase = "wait_boot", startedAt = 0, stepAt = 0, logLines = {} }
ALALive.scenario = T

local function log(msg)
    local line = "[ALALive] " .. tostring(msg)
    print(line)
    T.logLines[#T.logLines + 1] = line
end

local function finish(ok, summary)
    T.phase = "done"
    local status = (ok and "PASS " or "FAIL ") .. tostring(summary)
    log("RESULT " .. status)
    local A = ALifeAirwaves
    if A and type(A.counters) == "function" then
        log("COUNTERS " .. A.counters())
    end
    local writer = getFileWriter("ALALive_result.txt", true, false)
    writer:writeln(status)
    if A and type(A.counters) == "function" then
        writer:writeln("counters: " .. A.counters())
    end
    for _, ln in ipairs(T.logLines) do
        writer:writeln(ln)
    end
    writer:close()
end

local function giveAndTurnOnRadio(player)
    local inv = player:getInventory()
    local radio = inv:AddItem("Radio.WalkieTalkie4") or inv:AddItem("Base.WalkieTalkie4") or inv:AddItem("Radio.WalkieTalkie5")
    if radio and type(radio.getDeviceData) == "function" then
        local dd = radio:getDeviceData()
        if dd then
            pcall(function() dd:setIsBatteryPowered(false) end)
            pcall(function() dd:setPower(1.0) end)
            pcall(function() dd:setIsTurnedOn(true) end)
            pcall(function() dd:setChannel(94200) end)
        end
    end
    inv:AddItem("Base.Pen")
    for _ = 1, 3 do inv:AddItem("Base.Bandage") end
    for _ = 1, 2 do inv:AddItem("Base.Bullets9mmBox") end
    inv:AddItem("Base.PetrolCan")
    for _ = 1, 25 do inv:AddItem("Base.Money") end
    return radio
end

local function tickScenario()
    if T.phase == "done" then return end
    local player = getSpecificPlayer(0)
    if not player then return end
    local now = getTimestampMs()
    if T.startedAt == 0 then
        T.startedAt = now
        T.stepAt = now
        player:setGodMod(true)
        player:setInvisible(true)
        log("IN_WORLD x=" .. math.floor(player:getX()) .. " y=" .. math.floor(player:getY()))
    end
    if now - T.startedAt > 180000 then
        return finish(false, "timeout in phase " .. tostring(T.phase))
    end

    local P = ProjectALife
    local C = ALifeCaravans
    local A = ALifeAirwaves

    if T.phase == "wait_boot" then
        if not (P and P.Runtime and P.Runtime.started and A and A.Boot and A.Boot.installed) then
            return
        end
        if C and C.Boot and not C.Boot.installed then
            return
        end
        log("STEP 1 PASS: ProjectALife, ALifeCaravans=" .. tostring(C and C.Boot and C.Boot.installed) .. ", and ALifeAirwaves booted")
        A.ZomboidRadio.load(nil)
        local chCount = 0
        for _ in pairs(A.ZomboidRadio.channels or {}) do chCount = chCount + 1 end
        log("STEP 1b: ZomboidRadio channels registered=" .. tostring(chCount))
        T.phase = "equip_and_tune"
        T.stepAt = now

    elseif T.phase == "equip_and_tune" then
        if now - T.stepAt < 1500 then return end
        local radio = giveAndTurnOnRadio(player)
        if not radio then return finish(false, "could not create WalkieTalkie4 in player inventory") end
        local scan = A.RadioCheck.scanPlayerRadios(player)
        local canWrite = A.RadioCheck.canWriteOnMap(player)
        if not (scan.hasRadio and scan.hasPowered and canWrite) then
            return finish(false, "scanPlayerRadios/canWriteOnMap failed: hasRadio=" .. tostring(scan.hasRadio)
                .. " hasPowered=" .. tostring(scan.hasPowered) .. " canWrite=" .. tostring(canWrite))
        end
        local okTune, freq = A.RadioCheck.tunePlayerRadio(player, 101600)
        if not okTune or freq ~= 101600 then
            return finish(false, "tunePlayerRadio failed")
        end
        log("STEP 2 PASS: WalkieTalkie4 powered & tuned to 101.6 MHz, Pen detected")
        T.phase = "broadcasts"
        T.stepAt = now

    elseif T.phase == "broadcasts" then
        if now - T.stepAt < 1500 then return end
        local b1 = A.Director.emitBroadcast(now, "air_sighting")
        local b2 = A.Director.emitBroadcast(now, "air_caravan")
        if not b1 or not b2 or A.metrics.broadcasts < 2 then
            return finish(false, "emitBroadcast failed")
        end
        log("STEP 3 PASS: Live broadcasts emitted & auto-marked (broadcasts=" .. A.metrics.broadcasts .. " mapMarks=" .. A.metrics.mapMarks .. ")")
        T.phase = "sos_contract"
        T.stepAt = now

    elseif T.phase == "sos_contract" then
        if now - T.stepAt < 1500 then return end
        local sos = A.Director.createSOS(now, "medical", player)
        if not sos or sos.state ~= "open" then
            return finish(false, "createSOS failed")
        end
        local okAcc = A.Director.acceptSOS(player, sos.id)
        if not okAcc or sos.state ~= "accepted" then
            return finish(false, "acceptSOS failed")
        end
        player:teleportTo(sos.x, sos.y, 0)
        T.activeSOS = sos
        log("STEP 4a PASS: SOS created & accepted (" .. tostring(sos.id) .. " at " .. sos.x .. "," .. sos.y .. ")")
        T.phase = "sos_fulfill"
        T.stepAt = now

    elseif T.phase == "sos_fulfill" then
        if now - T.stepAt < 2500 then return end
        local sos = T.activeSOS
        player:teleportTo(sos.x, sos.y, 0)
        A.Director.materializeSOS(sos, player)
        local okFul, given = A.Director.fulfillSOS(player, sos.id)
        if not okFul or sos.state ~= "completed" then
            return finish(false, "fulfillSOS failed for " .. tostring(sos.id))
        end
        log("STEP 4b PASS: SOS fulfilled, rewards granted=" .. tostring(given and #given or 0)
            .. " favor=" .. tostring(A.Ledger.favor(A.playerKey(player), sos.factionId)))
        T.phase = "supply_dispatch"
        T.stepAt = now

    elseif T.phase == "supply_dispatch" then
        if now - T.stepAt < 2000 then return end
        A.Ledger.open().cooldowns.dispatchByPlayer = {}
        local okDisp, disp = A.Director.requestDispatch(player, "pkg_medical")
        if not okDisp or not disp or disp.state ~= "ready" then
            return finish(false, "requestDispatch failed: " .. tostring(disp))
        end
        player:teleportTo(disp.x, disp.y, 0)
        T.activeDrop = disp
        log("STEP 5a PASS: Supply drop dispatched (" .. tostring(disp.id) .. " at " .. disp.x .. "," .. disp.y .. ")")
        T.phase = "supply_claim"
        T.stepAt = now

    elseif T.phase == "supply_claim" then
        if now - T.stepAt < 2000 then return end
        local disp = T.activeDrop
        player:teleportTo(disp.x, disp.y, 0)
        local okClaim, items = A.Director.claimDispatch(player, disp.id)
        if not okClaim or disp.state ~= "claimed" then
            return finish(false, "claimDispatch failed")
        end
        A.Ledger.open().cooldowns.intelByPlayer = {}
        local okIntel, report = A.Director.requestIntel(player, "Muldraugh")
        if not okIntel or not report then
            return finish(false, "requestIntel failed")
        end
        log("STEP 5b PASS: Supply drop claimed (items=" .. tostring(items and #items or 0)
            .. ") & Muldraugh Recon Intel received (squads=" .. tostring(report.squads) .. ")")
        T.phase = "ui_window"
        T.stepAt = now

    elseif T.phase == "ui_window" then
        if now - T.stepAt < 1500 then return end
        local okOpen, win = A.Style.openWindow(0, "log")
        if not okOpen or not win then
            return finish(false, "ALA_AirwavesWindow failed to open")
        end
        win:prerender()
        win:onMarkMap()
        win:onSelectTab({ tabId = "sos" })
        win:prerender()
        win:onSelectTab({ tabId = "dispatch" })
        win:prerender()
        win:close()
        if A.metrics.errors > 0 then
            return finish(false, "ALifeAirwaves logged errors=" .. tostring(A.metrics.errors))
        end
        log("STEP 6 PASS: ALA_AirwavesWindow opened, rendered all 3 tabs, marked map, and closed with 0 errors")
        return finish(true, "All 6 in-game SP verification steps passed with 0 errors")
    end
end

Events.OnTick.Add(function()
    local ok, err = pcall(tickScenario)
    if not ok and T.phase ~= "done" then
        finish(false, "Lua exception in scenario: " .. tostring(err))
    end
end)
