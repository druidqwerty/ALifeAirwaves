-- Test-only menu navigation for isolated SP verification (never sends OS keyboard/mouse input).
ALALive = ALALive or { once = {} }
local T = ALALive

function T.log(text)
    print("[ALALive] " .. tostring(text))
end

function T.first(key)
    if T.once[key] then return false end
    T.once[key] = true
    return true
end

local function visible(panel)
    return panel and panel:isVisible()
end

local function tuneSandbox()
    local options = getSandboxOptions()
    for name, value in pairs({
        Zombies = 4,
        DayLength = 26,
        StartTime = 2,
        ["ZombieConfig.PopulationMultiplier"] = 0.0,
        ["ZombieConfig.PopulationStartMultiplier"] = 0.0,
        ["ZombieConfig.PopulationPeakMultiplier"] = 0.0,
    }) do
        if options:getOptionByName(name) then options:set(name, value) end
    end
    options:toLua()
end

local function menuTick()
    local main = MainScreen and MainScreen.instance
    if not main or main.inGame or getSpecificPlayer(0) then return end
    local now = getTimestampMs()
    T.menuAt = T.menuAt or now
    if now - T.menuAt < 4000 then return end
    getCore():setOptionPauseOnFocusloss(false)
    getCore():setOptionShowSurvivalGuide(false)
    if visible(main.worldSelect) and T.first("world") then
        T.log("world select next")
        main.worldSelect:clickNext()
    elseif visible(main.mapSpawnSelect) and T.first("spawn") then
        local panel = main.mapSpawnSelect
        for index, row in ipairs(panel.listbox.items) do
            local region = row.item and row.item.region
            if region and string.find(region.name, "Muldraugh", 1, true) then
                panel.listbox.selected = index
                break
            end
        end
        panel.textEntry:setText("ALALive")
        T.log("spawn next")
        panel:clickNext()
    elseif visible(main.sandOptions) and T.first("sandbox") then
        main.sandOptions:onOptionMouseDown({ internal = "PLAY" }, 0, 0)
        tuneSandbox()
        T.log("sandbox configured")
    elseif visible(main.charCreationProfession) and T.first("profession") then
        main.charCreationProfession:onOptionMouseDown({ internal = "NEXT" }, 0, 0)
        T.log("profession next")
    elseif visible(main.charCreationMain) and T.first("appearance") then
        tuneSandbox()
        local region = main.mapSpawnSelect.selectedRegion
        if region then
            for name in pairs(region.points) do
                region.points[name] = { { posX = 10637, posY = 10267, posZ = 0 } }
            end
        end
        main.charCreationMain:onOptionMouseDown({ internal = "NEXT" }, 0, 0)
        T.log("appearance play")
    elseif T.first("start") then
        T.log("new isolated Sandbox")
        main.mainOptions:setVisible(false)
        main.soloScreen.selectedItem = { data = { mode = "Sandbox" } }
        main.soloScreen:clickPlay()
    end
end

Events.OnFETick.Add(function()
    local ok, err = pcall(menuTick)
    if not ok and T.first("menu-error") then T.log("ERROR menu " .. tostring(err)) end
end)

Events.OnGameStart.Add(function()
    getCore():setOptionPauseOnFocusloss(false)
    getCore():setOptionShowSurvivalGuide(false)
    if SurvivalGuide and SurvivalGuide.instance and SurvivalGuide.instance:isVisible() then
        SurvivalGuide.instance:onClose()
    end
    setGameSpeed(1)
    T.log("OnGameStart guide closed, speed=" .. tostring(getGameSpeed()))
end)

T.log("menu driver loaded")
