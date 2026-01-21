-- =============================================================================
-- Dalgona Game - Rock Interaction System
-- Single Player Mode: Spawns a rock at player spawn location
-- =============================================================================

local rockProp = nil
local rockCoords = nil
local isNearRock = false
local isMinigameActive = false
local rockBlip = nil
local currentPattern = nil

-- Check if startMinigame is available, if not try to load it
if type(startMinigame) ~= "function" then
    local ok, err = pcall(function()
        local status, result = pcall(require, 'client.minigame')
        if status and type(result) == "table" and type(result.startMinigame) == "function" then
            startMinigame = result.startMinigame
        end
    end)
    if not ok then
        print("^1[dalgona-game] Warning: Could not load minigame module: " .. tostring(err) .. "^7")
    end
end

-- Rock model hash from config
local ROCK_MODEL = Config.RockProp.ModelHash or `prop_rock_4_c`

-- Cleanup existing rocks on resource start
local function cleanupExistingRocks()
    -- Find and delete any existing rock props
    local props = GetGamePool('CObject')
    
    for _, prop in ipairs(props) do
        if DoesEntityExist(prop) then
            local propModel = GetEntityModel(prop)
            if propModel == ROCK_MODEL then
                DeleteEntity(prop)
                print('^2[Dalgona Game]^7 Rimosso vecchia roccia esistente')
            end
        end
    end
end

-- =============================================================================
-- Rock Spawning Functions
-- =============================================================================

local function spawnRock()
    if rockProp then
        DeleteEntity(rockProp)
    end
    
    -- Use fixed position from config
    rockCoords = Config.FixedPositions.Rock
    
    -- Get ground z coordinate more accurately
    local success, groundZ = GetGroundZFor_3dCoord(rockCoords.x, rockCoords.y, 1000.0, 0.0, false)
    if success then
        rockCoords = vec3(rockCoords.x, rockCoords.y, groundZ + 0.2) -- Small offset to prevent sinking
        print('^2[Dalgona Game]^7 Ground Z trovato per roccia: ' .. groundZ)
    else
        -- Fallback: use raycast
        local groundZ = rockCoords.z
        local foundGround, z = GetGroundZFor_3dCoord(rockCoords.x, rockCoords.y, 1000.0, false)
        
        if foundGround then
            groundZ = z
            print(string.format('^2[Dalgona Game]^7 Ground Z trovato per roccia: %.6f', groundZ))
        else
            -- Fallback: usa un raycast se GetGroundZFor_3dCoord fallisce
            local rayHandle = StartShapeTestRay(
                rockCoords.x, rockCoords.y, 1000.0,
                rockCoords.x, rockCoords.y, -1000.0,
                1, -- flags: 1 = worldProbe
                0, -- ignoreEntity
                0  -- flags
            )
            
            local _, hit, hitCoords = GetShapeTestResult(rayHandle)
            
            if hit == 1 then
                groundZ = hitCoords.z
                print(string.format('^2[Dalgona Game]^7 Ground Z trovato con raycast: %.6f', groundZ))
            else
                groundZ = rockCoords.z
                print('^1[Dalgona Game]^7 Impossibile trovare il terreno per la roccia, usando Z predefinito')
            end
        end
    end
    
    -- Request and create model
    RequestModel(ROCK_MODEL)
    while not HasModelLoaded(ROCK_MODEL) do
        Wait(10)
    end
    
    rockProp = CreateObject(ROCK_MODEL, rockCoords.x, rockCoords.y, rockCoords.z, false, false, false)
    
    -- Place on ground properly
    PlaceObjectOnGroundProperly(rockProp)
    
    -- Set random rotation
    SetEntityRotation(rockProp, 0.0, 0.0, math.random(0, 360), 2, true)
    FreezeEntityPosition(rockProp, true)
    
    -- Get final position after ground placement
    local finalPos = GetEntityCoords(rockProp)
    rockCoords = finalPos
    
    -- Add blip if enabled
    if Config.RockProp.BlipEnabled then
        rockBlip = AddBlipForCoord(rockCoords.x, rockCoords.y, rockCoords.z)
        SetBlipSprite(rockBlip, Config.RockProp.BlipSprite or 486)
        SetBlipColour(rockBlip, Config.RockProp.BlipColor or 3)
        SetBlipScale(rockBlip, Config.RockProp.BlipScale or 0.7)
        SetBlipAsShortRange(rockBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.RockProp.BlipName or "Dalgona Stone")
        EndTextCommandSetBlipName(rockBlip)
    end
    
    print('^1[DEBUG]:^0 Rock spawned at: ' .. tostring(rockCoords))
end

-- =============================================================================
-- Proximity and Interaction Functions
-- =============================================================================

local function checkProximity()
    if not rockCoords or isMinigameActive then
        isNearRock = false
        return
    end
    
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local distance = #(playerPos - rockCoords)
    local interactionDist = Config.RockProp.InteractionDistance or 3.0
    isNearRock = distance < interactionDist
end

local function drawInteractionPrompt()
    if isNearRock and rockProp and not isMinigameActive then
        Draw3DText(rockCoords.x, rockCoords.y, rockCoords.z + 1.0, _U('rock_interact_prompt'))
        
        DrawMarker(
            1, rockCoords.x, rockCoords.y, rockCoords.z - 0.5,
            0.0, 0.0, 0.0,
            0.5, 0.5, 0.5,
            255, 165, 0, 200,
            false, false, 2, false, nil, nil, false
        )
    end
end

-- =============================================================================
-- Minigame Result Handlers
-- =============================================================================

local function onMinigameSuccess()
    debugPrint('Minigame succeeded!')
    
    TriggerServerEvent('dalgona-game:playerWonMinigame', currentPattern)
    Framework.showNotification(_U('minigame_success'))
    
    -- Simple success animation (no manual mode)
    PlayAnimation(PlayerPedId(), {
        dict = "mini@sprunk",
        name = "sprunk_ply",
        blendInSpeed = 1.0,
        blendOutSpeed = 1.0,
        duration = 2000,
        flag = 1 + 8,
        playbackRate = 0.0,
    })
    
    isMinigameActive = false
end

local function onMinigameFailed()
    debugPrint('Minigame failed!')
    
    Framework.showNotification(_U('minigame_failed'))
    
    -- Simple fail animation (no manual mode)
    PlayAnimation(PlayerPedId(), {
        dict = "missheistdockssetup1ig_10@base", 
        name = "dockhand_idle_a",
        blendInSpeed = 1.0,
        blendOutSpeed = 1.0,
        duration = 2000,
        flag = 1 + 8,
        playbackRate = 0.0,
    })
    
    isMinigameActive = false
end

-- =============================================================================
-- Main Interaction Handler
-- =============================================================================

local function handleInteraction()
    if isNearRock and rockProp and not isMinigameActive then
        -- Check if player has pietra grezza
        local hasPietra = exports.ox_inventory:Search('count', 'pietra_grezza') > 0
        if not hasPietra then
            -- Show notification
            TriggerEvent('ox_lib:notify', {
                type = 'error',
                description = 'Hai bisogno di una Pietra Grezza per provare a trasformarla in una Runa Magica!'
            })
            return
        end

        -- Hide any existing notification
        SendNUIMessage({hideNotification = true})

        isMinigameActive = true
        Framework.showNotification(_U('minigame_started'))

        -- Fixed duration: 2 minutes
        local timeLimit = 120

        -- Show timer UI
        SendNUIMessage({show = true, hideParticipantsCounter = true})
        startTimer(timeLimit)

        -- Start the minigame
        local hasSucceed = false
        local pattern = startRoulette(nil)
        currentPattern = pattern
        if type(startMinigame) == "function" then
            hasSucceed = startMinigame(pattern, function()
                return true
            end)
        else
            Framework.showNotification(_U('minigame_failed') .. " (Error: Minigame not loaded)")
            print("^1[dalgona-game] ERROR: startMinigame function not available! Check that minigame.lua is loaded correctly.^7")
        end

        -- Hide timer UI
        hideTimer()
        SendNUIMessage({show = false})

        -- Handle result
        if hasSucceed then
            onMinigameSuccess()
        else
            onMinigameFailed()
        end
    end
end

-- =============================================================================
-- Commands
-- =============================================================================

-- Simple teleport command: /runatp
RegisterCommand('runatp', function()
    if rockCoords then
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, rockCoords.x, rockCoords.y, rockCoords.z + 1.0)
        Framework.showNotification(_U('rock_too_far'))
        debugPrint('Teleported to rock at: ' .. tostring(rockCoords))
    else
        Framework.showNotification('Rock not spawned yet. Try again later.')
    end
end, false)

-- =============================================================================
-- Event Handlers
-- =============================================================================

-- Respawn rock event
RegisterNetEvent('dalgona-game:respawnRock', function()
    spawnRock()
end)

-- Update rock position event
RegisterNetEvent('dalgona-game:updateRockPosition', function(newPos)
    if rockProp then
        DeleteEntity(rockProp)
    end
    
    rockCoords = newPos
    RequestModel(ROCK_MODEL)
    while not HasModelLoaded(ROCK_MODEL) do
        Wait(10)
    end
    
    rockProp = CreateObject(ROCK_MODEL, rockCoords.x, rockCoords.y, rockCoords.z, false, false, false)
    FreezeEntityPosition(rockProp, true)
    
    if rockBlip then
        SetBlipCoords(rockBlip, rockCoords.x, rockCoords.y, rockCoords.z)
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if rockProp then
            DeleteEntity(rockProp)
        end
        if rockBlip then
            RemoveBlip(rockBlip)
        end
    end
end)

-- =============================================================================
-- Main Thread
-- =============================================================================

CreateThread(function()
    Wait(2000)
    
    if not Config.RockProp.Enabled then
        return
    end
    
    -- Cleanup existing rocks first
    cleanupExistingRocks()
    
    spawnRock()
    
    while true do
        Wait(0)
        checkProximity()
        drawInteractionPrompt()
        
        if isNearRock and IsControlJustPressed(0, 303) then -- U
            handleInteraction()
        end
    end
end)
