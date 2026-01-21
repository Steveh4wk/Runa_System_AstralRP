--
-- Start marker (lobby) for entering the game 
--

local timeLeftBeforeGameStarts = 0
local playersCount = 0
local totalReward = 0
local insideStartPoint = false
local startPoint = {
    zone = nil,
    drawZone = nil,
    blip = nil,
    bench = nil,
}
local insideDrawMarkerPoint = false
local isGameAlreadyStarted = false
local isEnoughMoney = true
local isEnoughItem = true

-- Framework shortcuts
local lib = exports['ox_lib']
local target = exports['ox_target']

RegisterNetEvent(EVENTS['timeLeftBeforeGameStarts'], function(v)
    timeLeftBeforeGameStarts = v
end)

RegisterNetEvent(EVENTS['refreshGameInfo'], function(v)
    playersCount = v.playersCount
    totalReward = v.totalReward
    isGameAlreadyStarted = false
    isEnoughMoney = true
    isEnoughItem = true
end)

local function createStartPoint()
    -- Rimuovo CircleZone - uso sistema base
    local blip = nil
    if Config.StartPointBlip.Enabled then
        blip = AddBlipForCoord(Config.StartPoint.x,Config.StartPoint.y,Config.StartPoint.z)
        SetBlipSprite(blip, Config.StartPointBlip.Id)
        SetBlipColour(blip, Config.StartPointBlip.Color)
        SetBlipScale(blip, Config.StartPointBlip.Scale)
        SetBlipDisplay(blip, 4)
        SetBlipAsShortRange(blip, true)
        SetBlipHighDetail(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(_U("squid_game"))
        EndTextCommandSetBlipName(blip)
    end

    -- Add workbench for testing rune upgrades
    local benchCoords = vec3(Config.StartPoint.x + 5.0, Config.StartPoint.y, Config.StartPoint.z)
    local bench = CreateObject(GetHashKey('prop_tool_bench02'), benchCoords.x, benchCoords.y, benchCoords.z, false, false, false)
    SetEntityHeading(bench, 0.0)
    FreezeEntityPosition(bench, true)

    CreateThread(function()
        while true do
            Wait(0)
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - Config.StartPoint)
            
            if distance <= Config.StartPointSize then
                insideStartPoint = true
                timeLeftBeforeGameStarts = 0
                isGameAlreadyStarted = false
                isEnoughMoney = true
                isEnoughItem = true
                
                if not gameStarted and insideStartPoint then
                    TriggerServerEvent(EVENTS['joinLobby'])
                end
                
                local gameInfoText = ""
                
                if gameStarted then
                    gameInfoText = "~r~GAME STARTED"
                else
                    local seconds = math.ceil(timeLeftBeforeGameStarts / 1000)

                    if isGameAlreadyStarted then
                        gameInfoText = _U("game_already_started")
                    elseif not isEnoughMoney and not isEnoughItem then
                        gameInfoText = _U("not_enaugh_money_and_item", Config.Fee)
                    elseif not isEnoughMoney then
                        gameInfoText = _U("not_enaugh_money", Config.Fee)
                    elseif not isEnoughItem then
                        gameInfoText = _U("no_required_item")
                    else
                        gameInfoText = _U("game_waiting", seconds, totalReward)
                    end
                end
    
                Draw3DText(Config.StartPoint.x, Config.StartPoint.y, Config.StartPoint.z + 1.0, gameInfoText)
                DrawIndicator(vec3(Config.StartPoint.x, Config.StartPoint.y, Config.StartPoint.z + 2.0), {255, 255, 255, 255})
                DrawMarker(
                    1, -- type (6 is a vertical and 3D ring)
                    vec3(Config.StartPoint.x, Config.StartPoint.y, Config.StartPoint.z - 2.0),
                    0.0, 0.0, 0.0, -- direction (?)
                    0.0, 0.0, 0.0, -- rotation (90 degrees because of right is really vertical)
                    Config.StartPointSize * 2.0, Config.StartPointSize * 2.0, 4.0, -- scale
                    Config.StartPointColor[1], Config.StartPointColor[2], Config.StartPointColor[3], Config.StartPointColor[4],
                    false, -- bob
                    true, -- face camera
                    2, -- dunno, lol, 100% cargo cult
                    false, -- rotate?
                    nil, nil, nil
                )
            else
                if not insideStartPoint and not gameStarted then
                    TriggerServerEvent(EVENTS['quitLobby'])
                end
                insideStartPoint = false
            end
        end
    end)
    FreezeEntityPosition(bench, true)

    exports.ox_target:addLocalEntity(bench, {
        {
            label = 'Test Potenziamento Rune',
            icon = 'fa-solid fa-gem',
            onSelect = function()
                TriggerEvent('rune:openMenu')
            end
        }
    })

    startPoint.bench = bench

    return { blip = blip }
end

local function destroyStartPoint()
    if startPoint.blip then
        RemoveBlip(startPoint.blip)
    end
    if startPoint.bench then
        DeleteEntity(startPoint.bench)
    end
    startPoint.blip = nil
    startPoint.bench = nil
end

local function onEnabled()
    isEnabled = true
    destroyStartPoint()
    startPoint.blip = createStartPoint().blip
end

local function onDisabled()
    isEnabled = false
    destroyStartPoint()

    -- leave game lobby
    if insideStartPoint and not gameStarted then
        TriggerServerEvent(EVENTS['quitLobby'])
    end
end

AddStateBagChangeHandler(STATEBAGS['startPointEnabled'], nil, function(bagName, key, value)
    if value == true then
        onEnabled()
    elseif value == false then
        onDisabled()
    end
end)

CreateThread(function()
    if Config.StartPointEnabled then
        onEnabled()
    end
end)

RegisterNetEvent(EVENTS['notifyGameAlreadyStarted'], function()
    Framework.showNotification(_U("game_already_started"))
    isGameAlreadyStarted = true
end)

RegisterNetEvent(EVENTS['notifyNotEnoughMoney'], function()
    Framework.showNotification(_U("not_enaugh_money", Config.Fee))
    isEnoughMoney = false
end)

RegisterNetEvent(EVENTS['notifyNotEnoughItem'], function()
    Framework.showNotification(_U('no_required_item'))
    isEnoughItem = false
end)

-- Funzione di pulizia sicura per ox_target
local function safeRemoveTargetEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end
    
    -- Prova a rimuovere la zona target in modo sicuro
    pcall(function()
        if target then
            exports.ox_target:removeLocalEntity(entity)
        end
    end)
end

-- Funzione di pulizia completa
local function cleanupStartPoint()
    -- Disabilita ox_target completamente prima della pulizia
    pcall(function()
        if target then
            exports.ox_target:disableTargeting()
        end
    end)
    
    -- Rimuovi le zone target in modo sicuro
    if startPoint and startPoint.bench then
        safeRemoveTargetEntity(startPoint.bench)
        -- Aspetta un frame prima di cancellare l'entity
        Wait(0)
        if DoesEntityExist(startPoint.bench) then
            DeleteEntity(startPoint.bench)
        end
        startPoint.bench = nil
    end
    
    -- Pulisci blip se esiste
    if startPoint and startPoint.blip and DoesBlipExist(startPoint.blip) then
        RemoveBlip(startPoint.blip)
        startPoint.blip = nil
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cleanupStartPoint()
end)