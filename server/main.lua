print('Game Init')

-- Rune Rewards Table
local RuneRewards = {
    dragon = {
        { item = 'runa_danno', amount = 1 },
        { item = 'pietra_grezza', amount = 1 }
    },
    star = {
        { item = 'runa_mp', amount = 1 }
    },
    triangle = {
        { item = 'runa_cdr', amount = 1 }
    },
    circle = {
        { item = 'runa_speed', amount = 1 }
    },
    square = {
        { item = 'runa_hp', amount = 1 }
    }
}

-- Rune Bonus
local RuneBonus = {
    runa_hp = 100,
    runa_danno = 100,
    runa_mp = 100,
    runa_cdr = 100,
    runa_speed = 100
}

-- Rune Configuration
local RUNE_CONFIG = {
    ['runa_hp'] = { name = 'Vita', image = 'nui://ox_inventory/web/images/runa_hp.png' },
    ['runa_danno'] = { name = 'Danno', image = 'nui://ox_inventory/web/images/runa_danno.png' },
    ['runa_mp'] = { name = 'Mana', image = 'nui://ox_inventory/web/images/runa_mp.png' },
    ['runa_cdr'] = { name = 'Cooldown', image = 'nui://ox_inventory/web/images/runa_cdr.png' },
    ['runa_speed'] = { name = 'Velocità', image = 'nui://ox_inventory/web/images/runa_speed.png' }
}

-- Upgrade Chances
local UpgradeChances = {
    [0] = 100, -- +0 -> +1
    [1] = 80,  -- +1 -> +2
    [2] = 60,  -- +2 -> +3
    [3] = 40,  -- +3 -> +4
    [4] = 20   -- +4 -> +5
}

-- Downgrade Chances (when upgrade fails)
local DowngradeChances = {
    [1] = 100, -- +1 fails -> becomes +0 (100% chance)
    [2] = 90,  -- +2 fails -> 90% chance to become +1, 10% to become +0
    [3] = 80,  -- +3 fails -> 80% chance to become +2, 20% to become +1
    [4] = 70,  -- +4 fails -> 70% chance to become +3, 30% to become +2
    [5] = 60   -- +5 fails -> 60% chance to become +4, 40% to become +3
}

if Config.AccumulativeReward then
    totalReward = math.max(GetResourceKvpInt('totalReward') or 0, 0)
else
    totalReward = 0
end

gameStarted = false
joinedPlayers = {}
allParticipants = {}

function isGameStarted()
    return gameStarted
end

function startGame()
    print('Server: Starting game')
    if gameStarted then
        return
    end

    if next(joinedPlayers) == nil then
        print('Server: No players joined, cannot start game')
        return
    end
    
    -- Store all participants during whole game
    allParticipants = {}
    for playerId,v in pairs(joinedPlayers) do
        table.insert(allParticipants, playerId)
    end

    -- Check for min players requirement
    if #allParticipants < Config.MinimumParticipants then
        for k,v in ipairs(allParticipants) do
            Framework.showNotification(v, _U('minimum_participatns_requirement_%s', Config.MinimumParticipants))
        end
        return
    end

    gameStarted = true

    -- Set player models, clothes and teleport them into game area
    -- Start cutscene
    local occupiedSpawnsByPlayers = {}
    local nextSpawnIdx = 1
    for playerId,v in pairs(joinedPlayers) do
        local playerPed = GetPlayerPed(playerId)
        local playerPedModel = GetEntityModel(playerPed)
        -- Set player model via server-side
        -- It's a workaround for crash: low-cola-sweet
        -- 13.01.2025
        -- Crash reproduction:
        -- Player 1 - MP female character with clothes
        -- Player 2 - Usual Ped (Hipster)
        -- And move below functionality to client-side into `gameInitiated` handler
        if Config.UsePedModelsInsteadOutfitsForPlayers then
            -- Set usual ped model
            if #Config.PlayerPeds > 0 then
                local hash = GetHashKey(Config.PlayerPeds[math.random(#Config.PlayerPeds)])
                SetPlayerModel(playerId, hash)
            end
        elseif Config.AllowCustomPeds then
            -- Just skip setting new model
        else
            -- Set MP male/female model
            if playerPedModel ~= GetHashKey("mp_m_freemode_01") and playerPedModel ~= GetHashKey("mp_f_freemode_01") then
                local maleModel = "mp_m_freemode_01"
                local femaleModel = "mp_f_freemode_01"
                local randomValue = math.random(0, 1)
                local selectedModel = randomValue == 1 and maleModel or femaleModel
                local model = GetHashKey(selectedModel)
                SetPlayerModel(playerId, model)
                while GetEntityModel(GetPlayerPed(playerId)) ~= model do
                    Wait(0)
                end
            end
        end

        -- Teleport
        local spawnIdx = nextSpawnIdx
        local coords = Config.SpawnCoords.GameStarted[spawnIdx]
        TriggerClientEvent(EVENTS['gameInitiated'], playerId, coords, playerPedModel)
        occupiedSpawnsByPlayers[tostring(spawnIdx)] = true

        -- Get next spawn point
        nextSpawnIdx = nextSpawnIdx + 1
        if nextSpawnIdx > #Config.SpawnCoords.GameStarted then
            nextSpawnIdx = 1
        end
    end

    -- Spawn participants NPC's with delay, to avoid issue with unloaded map
    for playerId,v in pairs(joinedPlayers) do
        TriggerClientEvent(EVENTS['spawnNPC'], playerId)
    end

    -- Wait for cutscene
    if Config.Cutscene.Enabled then
        local sequenceDuration = 0
        for k,v in ipairs(Config.Cutscene.Sequence) do
            sequenceDuration = sequenceDuration + v.transitionTime + v.waitTime
        end
        Wait(sequenceDuration)
        if not isGameStarted() then
            return
        end
    end

    -- Show initial countdown
    Wait(0)
    for playerId,v in pairs(joinedPlayers) do
        TriggerClientEvent(EVENTS['drawCountdown'], playerId)
    end
    Wait(3000)
    if not isGameStarted() then
        return
    end

    -- Get players amount
    local playersAmount = getPlayersCount()
    TriggerEvent(EVENTS['gameStarted'], playersAmount)

    -- Unfreeze players
    for playerId,v in pairs(joinedPlayers) do
        local playerPed = GetPlayerPed(playerId)
        TriggerClientEvent(EVENTS['gameStarted'], playerId, playersAmount)
    end

    -- Stop game when time is up
    CreateThread(function()
        local timestamp = GetGameTimer()
        while gameStarted and GetGameTimer() - timestamp < Config.GameDuration do
            Wait(1000)
        end
        if gameStarted then
            stopGame()
        end
    end)
    
    while gameStarted do
        Wait(100)
    end

    if gameStarted then
        stopGame()
    end
end

-- Get Player Inventory Event
RegisterNetEvent('rune:getInventory', function()
    local src = source
    print('Server: rune:getInventory chiamato dal player ' .. tostring(src))
    local inv = exports.ox_inventory
    
    -- Prova diversi metodi per ottenere l'inventario
    local inventory = inv:GetInventory(src) or inv:GetInventoryItems(src)
    if not inventory then 
        print('Server: ERRORE - Impossibile ottenere inventario per il player ' .. tostring(src))
        TriggerClientEvent('rune:inventoryResponse', src, {})
        return 
    end
    
    local playerRunes = {}
    
    -- Controlla se inventory è una tabella con items o direttamente gli items
    local itemsToCheck = inventory.items or inventory
    
    print('Server: L\'inventario contiene ' .. #itemsToCheck .. ' items per il player ' .. tostring(src))
    
    -- Controlla i galeoni del player
    local galeoniCount = inv:Search(src, 'count', 'galeoni')
    local hasEnoughGaleoni = galeoniCount >= 200
    
    print('Server: Player ha ' .. galeoniCount .. ' galeoni, sufficienti per upgrade: ' .. tostring(hasEnoughGaleoni))
    
    for _, item in pairs(itemsToCheck) do
        if item and item.name and (item.name:find('runa_') or item.name == 'pietra_grezza') then
            local level = 0
            if item.name:find('_divina') then
                level = 5
            else
                local l = item.name:match('_(%d+)$')
                if l then level = tonumber(l) end
            end
            
            print('Server: Trovato item runa: ' .. item.name .. ' quantità: ' .. (item.count or item.amount) .. ' livello: ' .. level)
            
            table.insert(playerRunes, {
                type = item.name,
                level = level,
                count = item.count or item.amount or 1
            })
        end
    end
    
    print('Server: Invio ' .. #playerRunes .. ' rune al player ' .. tostring(src))
    TriggerClientEvent('rune:inventoryResponse', src, {
        runes = playerRunes,
        galeoni = galeoniCount,
        hasEnoughGaleoni = hasEnoughGaleoni
    })
end)

-- Rune Upgrade Event (moved outside startGame so it's always available)
RegisterNetEvent('rune:upgrade', function(rune)
    local src = source
    print('Server: Evento rune:upgrade ricevuto per runa:', rune, 'da player:', src)
    print('Server: rune:upgrade triggered for rune: ' .. tostring(rune) .. ' by player ' .. tostring(src))

    -- Parse base rune and current level from item name
    local baseRune = rune
    local currentLevel = 0
    if rune:match('_divina$') then
        baseRune = rune:gsub('_divina', '')
        currentLevel = 5
    elseif rune:match('_(%d+)$') then
        local levelStr = rune:match('_(%d+)$')
        currentLevel = tonumber(levelStr)
        baseRune = rune:gsub('_' .. levelStr, '')
    end
    print('Server: Parsed baseRune:', baseRune, 'currentLevel:', currentLevel)

    -- Parse base rune and current level from item name
    local baseRune = rune
    local currentLevel = 0
    if rune:match('_divina$') then
        baseRune = rune:gsub('_divina', '')
        currentLevel = 5
    elseif rune:match('_(%d+)$') then
        local levelStr = rune:match('_(%d+)$')
        currentLevel = tonumber(levelStr)
        baseRune = rune:gsub('_' .. levelStr, '')
    end
    print('Server: Parsed baseRune: ' .. baseRune .. ', currentLevel: ' .. currentLevel)
        
    -- Check if player is actually in the dalgona game area
    local playerPed = GetPlayerPed(src)
    if not playerPed then
        print('Server: ERROR - Player ped not found!')
        return
    end

    -- Check if player is in the dalgona game area
    local playerCoords = GetEntityCoords(playerPed)
    local distanceToGame = #(playerCoords - vector3(Config.GameArea.x, Config.GameArea.y, Config.GameArea.z))

    if distanceToGame > 50 then -- More than 50 units away from game area
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 165, 0},
            multiline = true,
            args = {'[Incanta Pietra]', 'Devi essere vicino al tavolo da rune per upgradare!'}
        })
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'warning',
            description = 'Devi essere vicino al tavolo da rune per upgradare!'
        })
        return
    end

    print('Server: Player is in game area, distance: ' .. distanceToGame .. ', proceeding with upgrade')

    local inv = exports.ox_inventory
    if not inv then
        print('Server: ox_inventory not available')
        return
    end

    -- Verify the item exists
    local itemCount = inv:Search(src, 'count', rune)
    if itemCount < 1 then
        print('Server: Player does not have the item ' .. rune)
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {'[Incanta Pietra]', 'Non possiedi questa runa!'}
        })
        return
    end
    print('Server: Current level confirmed: ' .. currentLevel)

    -- Check if player has the required rune for upgrade
    if currentLevel < 0 or currentLevel >= 5 then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {'[Incanta Pietra]', 'Non puoi upgradeare questa runa (livello: ' .. currentLevel .. ')'}
        })
        return
    end

    -- Check if player has enough galeoni and remove them immediately
    local galeoniCount = inv:Search(src, 'count', 'galeoni')
    print('Server: Player has ' .. galeoniCount .. ' galeoni')
    if galeoniCount < 200 then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {'[Incanta Pietra]', 'Non hai abbastanza galeoni (costo: 200)'}
        })
        return
    end

    -- Remove galeoni immediately
    local galeoniRemoved = inv:RemoveItem(src, 'galeoni', 200)
    if not galeoniRemoved then
        print('Server: Failed to remove galeoni from player ' .. tostring(src))
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {'[Incanta Pietra]', 'ERRORE: Impossibile ritirare i galeoni'}
        })
        return
    end
    
    print('Server: Galeoni removed successfully, processing upgrade...')

    -- Process the upgrade immediately (client handles cooldown timer)
    CreateThread(function()
        -- Now process the actual upgrade
        local chance = UpgradeChances[currentLevel]

        local upgradeSuccess = math.random(100) <= chance
        print('Server: upgradeSuccess:', upgradeSuccess, 'chance:', chance)
        
        -- Invia subito il risultato al client per la visualizzazione nella fase 2
        if upgradeSuccess then
            local newLevel = currentLevel + 1
            local newRuneName = newLevel == 5 and baseRune .. ' Divina' or baseRune .. ' +' .. newLevel
            TriggerClientEvent('rune:upgradeResult', src, {
                success = true,
                message = 'SUCCESSO',
                newRune = {
                    type = newLevel == 5 and baseRune .. '_divina' or baseRune .. '_' .. newLevel,
                    level = newLevel,
                    name = newRuneName
                }
            })
            print('Sending success: true message: SUCCESSO (immediate)')
        else
            if currentLevel == 0 then
                TriggerClientEvent('rune:upgradeResult', src, {
                    success = false,
                    message = 'FALLITO',
                    newRune = {
                        type = 'pietra_grezza',
                        level = 0,
                        name = 'Pietra Grezza'
                    }
                })
                print('Sending success: false message: FALLITO - Pietra Grezza (immediate)')
            else
                local downgradeLevel = currentLevel - 1
                local newRuneName = downgradeLevel == 0 and baseRune or baseRune .. ' +' .. downgradeLevel
                local newRuneType = downgradeLevel == 0 and baseRune or baseRune .. '_' .. downgradeLevel
                TriggerClientEvent('rune:upgradeResult', src, {
                    success = false,
                    message = 'FALLITO',
                    newRune = {
                        type = newRuneType,
                        level = downgradeLevel,
                        name = newRuneName
                    }
                })
                print('Sending success: false message: FALLITO - ' .. newRuneName .. ' (immediate)')
            end
        end
        
        -- Aspetta 2 secondi prima di processare il drop/remove
        Wait(2000)
        
        if upgradeSuccess then
            -- Remove current level item and add the next level
            local removeItemName = rune
            local newLevel = currentLevel + 1
            local addItemName = newLevel == 5 and baseRune .. '_divina' or baseRune .. '_' .. newLevel

            local removeSuccess = inv:RemoveItem(src, removeItemName, 1)
            print('Server: RemoveItem result: ' .. tostring(removeSuccess) .. ' for item: ' .. removeItemName)

            if removeSuccess then
                -- Aggiungi la nuova runa solo dopo il successo completo
                inv:AddItem(src, addItemName, 1)
                print('Server: Success branch executed, addItemName:', addItemName)
                print('Upgraded ' .. baseRune .. ' from level ' .. currentLevel .. ' to level ' .. newLevel .. ' for player ' .. tostring(src))
                TriggerClientEvent('rune:upgradeComplete', src)
            else
                TriggerClientEvent('chat:addMessage', src, {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {'[Incanta Pietra]', 'ERRORE: Impossibile rimuovere ' .. removeItemName}
                })
                print('Failed to remove ' .. removeItemName .. ' for player ' .. tostring(src))
            end
        else
            upgradeSuccess = false
            -- On failure, downgrade the rune with variable chances
            if currentLevel == 0 then
                -- Level 0 failure: give pietra grezza instead of downgrading (can't go below 0)
                local removeSuccess = inv:RemoveItem(src, rune, 1)
                print('Server: RemoveItem (level 0) result: ' .. tostring(removeSuccess) .. ' for item: ' .. rune)
                
                if removeSuccess then
                    inv:AddItem(src, 'pietra_grezza', 1)
                    print('Failed upgrade ' .. rune .. ' from level ' .. currentLevel .. ' - became pietra grezza for player ' .. tostring(src))
                    TriggerClientEvent('rune:upgradeComplete', src)
                else
                    TriggerClientEvent('chat:addMessage', src, {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {'[Incanta Pietra]', 'ERRORE: Impossibile rimuovere ' .. rune}
                    })
                end
            else
                -- Calculate downgrade level based on chances
                local removeItemName = currentLevel == 5 and baseRune .. '_divina' or baseRune .. '_' .. currentLevel
                local removeSuccess = inv:RemoveItem(src, removeItemName, 1)
                print('Server: RemoveItem (level ' .. currentLevel .. ') result: ' .. tostring(removeSuccess) .. ' for item: ' .. removeItemName)

                if removeSuccess then
                    -- Sempre downgrade di 1 livello su fallimento
                    local downgradeLevel = currentLevel - 1
                    
                    local downgradeItemName = downgradeLevel == 0 and baseRune or baseRune .. '_' .. downgradeLevel
                    
                    -- Aggiungi la nuova runa solo dopo il successo completo
                    inv:AddItem(src, downgradeItemName, 1)
                    print('Server: Failure branch executed, downgradeItemName:', downgradeItemName, 'downgradeLevel:', downgradeLevel)
                    print('Failed upgrade ' .. baseRune .. ' from level ' .. currentLevel .. ' - downgraded to level ' .. downgradeLevel .. ' for player ' .. tostring(src))
                    TriggerClientEvent('rune:upgradeComplete', src)
                else
                    TriggerClientEvent('chat:addMessage', src, {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {'[Incanta Pietra]', 'ERRORE: Impossibile rimuovere ' .. removeItemName}
                    })
                end
            end
        end
    end)
end)

-- Pietra Grezza Use Event
RegisterNetEvent('pietra:use', function()
    local src = source
    print('Server: pietra:use triggered by player ' .. tostring(src))
    local inv = exports.ox_inventory

    if inv:RemoveItem(src, 'pietra_grezza', 1) then
        print('Server: pietra_grezza removed, triggering startMinigame for player ' .. tostring(src))
        TriggerClientEvent('dalgona:startMinigame', src)
    else
        print('Server: Failed to remove pietra_grezza for player ' .. tostring(src))
        -- Send parchment notification
        TriggerClientEvent('showUpgradeNotification', src, false, 'Hai bisogno di una Pietra Grezza per provare a trasformarla in una Runa Magica!')
    end
end)

-- Pietra Grezza Remove Event (for roulette)
RegisterNetEvent('pietra:remove', function(amount)
    local src = source
    amount = amount or 1
    print('Server: pietra:remove triggered by player ' .. tostring(src) .. ' amount: ' .. amount)
    local inv = exports.ox_inventory

    if inv:RemoveItem(src, 'pietra_grezza', amount) then
        print('Server: pietra_grezza removed for roulette, player ' .. tostring(src))
    else
        print('Server: Failed to remove pietra_grezza for roulette, player ' .. tostring(src))
    end
end)


function getRewardPerPlayer()
    if #allParticipants > 0 then
        return math.floor(totalReward / #allParticipants)
    else
        return 0
    end
end

function stopGame()
    -- Calculate reward per player
    local rewardPerPlayer = getRewardPerPlayer()

    -- Process players
    for playerId,v in pairs(joinedPlayers) do

        -- Check if player succeed
        local succeed = hasPlayerSucceed(playerId) 
        
        -- Give reward
        if succeed then
            giveRewardToPlayer(playerId, rewardPerPlayer)
            totalReward = totalReward - rewardPerPlayer
        end

        -- Reset player
        resetPlayer(playerId, succeed)
    end

    joinedPlayers = {}

    -- Erase all participants when the game stopped
    allParticipants = {}

    -- Keep reward for next game / reset reward
    if Config.AccumulativeReward then
        SetResourceKvpInt('totalReward', totalReward)
    else
        totalReward = 0
    end

    gameStarted = false

    TriggerEvent(EVENTS['gameOver'])
end

function resetPlayer(playerId, didSucceed)
    local coords = nil
    if didSucceed then
        local successSpawns = Config.SpawnCoords.GameSuccess
        if #successSpawns > 0 then
            coords = successSpawns[math.random(#successSpawns)]
        end
    else
        local failedSpawns = Config.SpawnCoords.GameFailed
        if #failedSpawns > 0 then
            local playerPed = GetPlayerPed(playerId)
            coords = failedSpawns[math.random(#failedSpawns)]
        end
    end

    TriggerClientEvent(EVENTS['resetPlayer'], playerId, didSucceed, coords)
end

function playerFailed(playerId)
    -- Remove player from the list of joined players
    joinedPlayers[tostring(playerId)] = nil

    -- Reset player
    resetPlayer(playerId, false)

    -- If we still have players - notify about changed players count
    if next(joinedPlayers) ~= nil then
        TriggerEvent(EVENTS['onPlayersAmountChanged'])
        return
    end

    -- Stop the game if there no more players
    stopGame()
end

AddEventHandler("playerDropped", function(reason)
    local playerId = source
    playerFailed(playerId)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then

    end
end)

-- Single Player Mode: Handle player winning the minigame via rock interaction
RegisterNetEvent('dalgona-game:playerWonMinigame')
AddEventHandler('dalgona-game:playerWonMinigame', function(pattern)
    local playerId = source
    
    print('Player ' .. tostring(playerId) .. ' won the minigame with pattern: ' .. tostring(pattern))
    
    -- Calculate reward amount (2x for sword pattern)
    local itemMultiplier = (pattern == 'sword') and 2 or 1
    
    -- Give diamond reward if configured
    if Config.RewardItem and Config.RewardItem ~= '' then
        local success = exports.ox_inventory:AddItem(playerId, Config.RewardItem, itemMultiplier)
        if success then
            local msg = itemMultiplier > 1 and _U('you_received_item_multiplier', Config.RewardItem, itemMultiplier) or _U('you_received_item', Config.RewardItem)
            TriggerClientEvent('chat:addMessage', playerId, {
                color = { 0, 200, 255},
                multiline = true,
                args = {Config.GameName, msg}
            })
            print('Successfully gave ' .. Config.RewardItem .. ' x' .. itemMultiplier .. ' to player ' .. tostring(playerId))
        else
            TriggerClientEvent('chat:addMessage', playerId, {
                color = { 255, 0, 0},
                multiline = true,
                args = {Config.GameName, 'Errore: Impossibile dare ' .. Config.RewardItem}
            })
            print('Failed to give ' .. Config.RewardItem .. ' to player ' .. tostring(playerId))
        end
    end
    
    -- Check if pattern exists in RuneRewards table
    if RuneRewards[pattern] then
        -- Give rune rewards based on pattern
        for _, reward in ipairs(RuneRewards[pattern]) do
            local success = exports.ox_inventory:AddItem(playerId, reward.item, reward.amount)
            if success then
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = { 0, 255, 0},
                    multiline = true,
                    args = {Config.GameName, 'Hai ricevuto: ' .. reward.item .. ' x' .. reward.amount}
                })
                print('Successfully gave ' .. reward.item .. ' x' .. reward.amount .. ' to player ' .. tostring(playerId))
            else
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = { 255, 0, 0},
                    multiline = true,
                    args = {Config.GameName, 'Errore: Impossibile dare ' .. reward.item}
                })
                print('Failed to give ' .. reward.item .. ' to player ' .. tostring(playerId))
            end
        end
    end

    -- Give money reward if configured
    if totalReward > 0 then
        Framework.giveMoney(playerId, totalReward)
        totalReward = 0
        if Config.AccumulativeReward then
            SetResourceKvpInt('totalReward', 0)
        end
    end
end)

-- Single Player Mode: Handle player winning the minigame (correct event handler)
RegisterNetEvent('dalgona:giveReward')
AddEventHandler('dalgona:giveReward', function(pattern)
    local playerId = source
    
    print('Player ' .. tostring(playerId) .. ' won minigame with pattern: ' .. tostring(pattern))
    
    -- Check if pattern exists in RuneRewards table
    if RuneRewards[pattern] then
        -- Give rune rewards based on pattern
        for _, reward in ipairs(RuneRewards[pattern]) do
            local success = exports.ox_inventory:AddItem(playerId, reward.item, reward.amount)
            if success then
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = { 0, 255, 0},
                    multiline = true,
                    args = {Config.GameName, 'Hai ricevuto: ' .. reward.item .. ' x' .. reward.amount}
                })
                print('Successfully gave ' .. reward.item .. ' x' .. reward.amount .. ' to player ' .. tostring(playerId))
            else
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = { 255, 0, 0},
                    multiline = true,
                    args = {Config.GameName, 'Errore: Impossibile dare ' .. reward.item}
                })
                print('Failed to give ' .. reward.item .. ' to player ' .. tostring(playerId))
            end
        end
    else
        -- Fallback to default reward if pattern not found
        if Config.RewardItem and Config.RewardItem ~= '' then
            local success = exports.ox_inventory:AddItem(playerId, Config.RewardItem, 1)
            if success then
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = { 0, 200, 255},
                    multiline = true,
                    args = {Config.GameName, _U('you_received_item', Config.RewardItem)}
                })
            else
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = { 255, 0, 0},
                    multiline = true,
                    args = {Config.GameName, 'Errore: Impossibile dare ' .. Config.RewardItem}
                })
            end
        end
    end
    
    -- Give money reward if configured
    if totalReward > 0 then
        Framework.giveMoney(playerId, totalReward)
        totalReward = 0
        if Config.AccumulativeReward then
            SetResourceKvpInt('totalReward', 0)
        end
    end
end)
