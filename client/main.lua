gameInitiated = false
gameStarted = false

-- Rimuovo BoxZone/PolyZone - non utilizzato
insideGameZone = false

function restrictPlayerOnTick()
    local playerPed = PlayerPedId()

    if Config.EnableGodmode then
        SetEntityInvincible(playerPed, true)
        SetPlayerInvincible(PlayerId(), true)
    end

    if Config.InGameTick then
        Config.InGameTick(playerPed)
    end
end

RegisterNetEvent(EVENTS['gameStarted'], function()
    gameStarted = true
end)

RegisterNetEvent(EVENTS['resetPlayer'], function(didSucceed, coords)
    local playerPed = PlayerPedId()

    -- Reset state
    hideTimer()
    gameStarted = false
    SetTimeout(5000, function()
        SendNUIMessage({
            stopSong = true,
        })
    end)

    -- Show notification
    Framework.showNotification(_U("game_finished"))

    -- Immitate player's death
    local IK_Head = 12844
    if not didSucceed then
        -- Set to ragdoll (immitate death)
        ClearPedTasks(playerPed)
        SetPedToRagdoll(playerPed, 6000, 6000, 0, 0, 0, 0)

        -- Make a thread, because we expect delays in playin sound or visual effect
        CreateThread(function()
            -- Blood headshot effect
            callBloodHeadshotEffectOnPed(playerPed)

            -- Play shot sound
            local coords = GetEntityCoords(playerPed)
            local isNetworked = true
            PlayPistolSoundFrontend()
            PlayPistolSound(coords, isNetworked)
        end)
        
        Wait(1500)
    end

    if didSucceed then
        SendNUIMessage({
            playSong = 'win.wav',
        })
    end

    -- Set player on position
    if coords then
        SetEntityCoords(playerPed, coords)
    end

    -- Restore skin
    if Config.ChangePlayerSkin then
        restorePlayerSkin()
    end

    cleanUpNPCsAndProps()
    cleanupAllDecals()

    gameInitiated = false
end)

RegisterNetEvent(EVENTS['gameInitiated'], function(coords, lastPlayerModel)
    debugPrint('Client: Game initiated, teleporting to coords: ' .. tostring(coords))
    gameInitiated = true

    hideTimer()
    
    -- Set Player Camera looking to direction
    -- SetGameplayCoordHint(Config.CarouselCoords.x, Config.CarouselCoords.y, Config.CarouselCoords.z, 500, 500, 500)

    -- Set player clothes
    if Config.ChangePlayerSkin then
        savePlayerSkin(lastPlayerModel)
        setPlayerSkinForGame()
    end

    -- Wait for the end of game
    while gameInitiated do
        Wait(0)
        restrictPlayerOnTick()  
    end

    -- Disable godmode if was enabled
    if Config.EnableGodmode then
        local playerPed = PlayerPedId()
        SetEntityInvincible(playerPed, false)
        SetPlayerInvincible(PlayerId(), false)
    end
end)

-- Rune Upgrade NPC - Commented out due to ox_compat issues
-- local NPC_COORDS = vec4(1234.5, 567.8, 32.1, 90.0)

-- CreateThread(function()
--     local model = `a_m_m_farmer_01`
--     RequestModel(model)
--     while not HasModelLoaded(model) do Wait(0) end

--     local ped = CreatePed(0, model, NPC_COORDS.xyz, NPC_COORDS.w, false, true)
--     FreezeEntityPosition(ped, true)
--     SetEntityInvincible(ped, true)
--     SetBlockingOfNonTemporaryEvents(ped, true)

--     exports.ox_compat:addLocalEntity(ped, {
--         {
--             label = 'Potenziamento Rune',
--             icon = 'fa-solid fa-gem',
--             onSelect = function()
--                 TriggerEvent('rune:openMenu')
--             end
--         }
--     })
-- end)

-- RegisterNetEvent('rune:openMenu', function()
--     if not lib then
--         print('^1[Dalgona Game]^7 ox_lib not loaded, cannot open rune menu')
--         return
--     end
--     lib.registerContext({
--         id = 'rune_upgrade',
--         title = 'Potenziamento Rune (200 Galeoni)',
--         options = {
--             {
--                 title = 'Potenziamento Runa HP',
--                 onSelect = function()
--                     TriggerServerEvent('rune:upgrade', 'runa_hp')
--                 end
--             },
--             {
--                 title = 'Potenziamento Runa Danno',
--                 onSelect = function()
--                     TriggerServerEvent('rune:upgrade', 'runa_danno')
--                 end
--             },
--             {
--                 title = 'Potenziamento Runa MP',
--                 onSelect = function()
--                     TriggerServerEvent('rune:upgrade', 'runa_mp')
--                 end
--             },
--             {
--                 title = 'Potenziamento Runa CDR',
--                 onSelect = function()
--                     TriggerServerEvent('rune:upgrade', 'runa_cdr')
--                 end
--             },
--             {
--                 title = 'Potenziamento Runa Speed',
--                 onSelect = function()
--                     TriggerServerEvent('rune:upgrade', 'runa_speed')
--                 end
--             }
--         }
--     })
--     lib.showContext('rune_upgrade')
-- end)