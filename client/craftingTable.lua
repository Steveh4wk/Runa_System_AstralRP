local playerInventory = {}
local isMenuOpen = false
local isInitialized = false
local craftingTableProp = nil
local craftingTableCoords = nil
local isNearCraftingTable = false
local mainThread = nil

-- Framework shortcuts
local lib = exports['ox_lib']
local target = exports['ox_target']

-- Rune Configuration
local RUNE_CONFIG = {
    ['runa_hp'] = { name = 'Vita', color = '#ff6b6b', image = 'nui://ox_inventory/web/images/runa_hp.png' },
    ['runa_danno'] = { name = 'Danno', color = '#ffa500', image = 'nui://ox_inventory/web/images/runa_danno.png' },
    ['runa_mp'] = { name = 'Mana', color = '#0066ff', image = 'nui://ox_inventory/web/images/runa_mp.png' },
    ['runa_cdr'] = { name = 'Cooldown', color = '#00ff66', image = 'nui://ox_inventory/web/images/runa_cdr.png' },
    ['runa_speed'] = { name = 'Velocità', color = '#ffff00', image = 'nui://ox_inventory/web/images/runa_speed.png' }
}

-- Utility Functions
local function GetRuneData(runeType)
    return RUNE_CONFIG[runeType] or { name = runeType, color = '#ffffff', image = 'nui://ox_inventory/web/images/runa_hp.png' }
end

-- Menu Management
local function closeCraftingMenu()
    if not isMenuOpen then return end
    isMenuOpen = false

    SendNUIMessage({ showCrafting = false })
    SetNuiFocus(false, false)
    DisplayRadar(true)
    
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)
    SetPlayerControl(PlayerId(), true, 0)
    
    if target then
        pcall(function() exports.ox_target:enableTargeting() end)
    end
end

local function openCraftingMenu()
    if isMenuOpen then return end
    
    print('Client: Apertura menu crafting...')
    
    if target then
        pcall(function() exports.ox_target:disableTargeting() end)
    end
    
    -- Imposta il focus e mostra il menu con indicatore di caricamento
    SetNuiFocus(true, true)
    DisplayRadar(false)
    
    -- Mostra il menu con indicatore di caricamento
    SendNUIMessage({ 
        showCrafting = true,
        showLoading = true
    })
    
    -- Richiedi l'inventario
    print('Client: Richiesta inventario al server...')
    TriggerServerEvent('rune:getInventory')
    
    -- Il menu è già aperto con l'indicatore di caricamento
    isMenuOpen = true
    
    -- Debug: aggiungi un timeout per verificare se riceviamo la risposta
    Citizen.CreateThread(function()
        Wait(5000)
        if not playerInventory or #playerInventory == 0 then
            print('Client: ATTENZIONE: Nessuna risposta ricevuta dal server dopo 5 secondi!')
            print('Client: playerInventory esiste:', playerInventory ~= nil)
            print('Client: playerInventory count:', playerInventory and #playerInventory or 'nil')
        else
            print('Client: Risposta ricevuta correttamente dal server')
        end
    end)
end

-- Inventory & NUI Callbacks
RegisterNetEvent('rune:inventoryResponse', function(data)
    print('Client: Ricevuto rune:inventoryResponse con ' .. #data.runes .. ' items')
    print('Client: Dati ricevuti - galeoni:', data.galeoni, 'hasEnoughGaleoni:', data.hasEnoughGaleoni)
    
    playerInventory = data.runes
    local html = ''
    local hasRunes = {}
    local pietreCount = 0
    
    -- Estrai i dati dei galeoni
    local galeoniCount = data.galeoni or 0
    local hasEnoughGaleoni = data.hasEnoughGaleoni or false
    
    print('Client: Galeoni disponibili: ' .. galeoniCount .. ', sufficienti: ' .. tostring(hasEnoughGaleoni))

    -- Se non ci sono rune, mostra un messaggio
    if #data.runes == 0 then
        print('Client: Nessuna runa trovata nell\'inventario')
        html = html .. [[
            <div style="text-align: center; padding: 20px; background: rgba(255, 0, 0, 0.1); border-radius: 8px; border: 1px solid #ff6b6b; margin: 10px 0;">
                <p style="color: #ff6b6b; font-weight: bold; margin: 0;">Nessuna Runa Trovata</p>
                <p style="font-size: 14px; color: #ffaaaa; margin: 5px 0;">Non hai rune nell'inventario da potenziare</p>
                <p style="font-size: 12px; color: #aaaaaa; margin: 0;">Ottieni rune giocando al gioco Dalgona!</p>
            </div>
        ]]
        -- Mostra il menu con il messaggio di nessuna runa e nascondi caricamento
        SendNUIMessage({ 
            showCrafting = true,
            showLoading = false,
            updateRunes = html,
            galeoniInfo = {
                count = galeoniCount,
                hasEnough = hasEnoughGaleoni
            }
        })
        return
    end

    print('Client: Elaborazione ' .. #data.runes .. ' items dall\'inventario...')
    
    for _, item in ipairs(data.runes) do
        print('Client: Elaborazione item - tipo: ' .. item.type .. ', quantità: ' .. item.count .. ', livello: ' .. (item.level or 0))
        if item.type == 'pietra_grezza' then
            pietreCount = item.count
        else
            -- Mostriamo ogni entry dell'inventario (quindi ogni livello diverso)
            table.insert(hasRunes, item)
        end
    end

    print('Client: Trovate ' .. pietreCount .. ' pietre grezze e ' .. #hasRunes .. ' rune')

    -- Generazione HTML Pietre Grezze
    if pietreCount > 0 then
        html = html .. string.format([[
            <div style="text-align: center; padding: 10px; background: rgba(255, 255, 255, 0.1); border-radius: 8px; border: 1px solid #daa520; margin: 10px 0;">
                <p style="color: #daa520; font-weight: bold; margin: 0;">Pietra Grezza</p>
                <p style="font-size: 12px; color: #f4e4bc; margin: 0;">Quantità: %d</p>
            </div>
        ]], pietreCount)
    end

    -- Generazione HTML Rune
    for _, item in ipairs(hasRunes) do
        local baseType = item.type:gsub('_divina$', ''):gsub('_(%d+)$', '')
        local runeData = GetRuneData(baseType)
        local level = item.level or 0
        local levelText = level == 5 and ' (Divina)' or ' (+' .. level .. ')'
        
        -- Disabilita le rune Divine (livello 5)
        local isDisabled = level >= 5
        local statusText = isDisabled and 'Livello Massimo' or (level < 5 and 'Pronto per upgrade' or 'Non upgradeabile')
        
        -- Per le rune Divine, mostra un messaggio speciale
        if level >= 5 then
            levelText = ' (Divina)'
            statusText = 'Potere Massimo Raggiunto'
        end
        
        print('Client: Generazione HTML per ' .. item.type .. ' - ' .. runeData.name .. levelText .. ' - Disabilitato: ' .. tostring(isDisabled))
        
        local disabledStyle = isDisabled and 'opacity: 0.5; cursor: not-allowed; filter: grayscale(80%);' or 'cursor: pointer;'
        local disabledClass = isDisabled and 'disabled' or ''
        
        html = html .. string.format([[
            <div class="rune-square %s" data-rune="%s" style="margin: 10px; text-align: center; display: inline-block; %s transition: transform 0.2s, box-shadow 0.2s;">
                <img src="%s" style="width: 60px; height: 60px; border-radius: 50%%; box-shadow: 0 0 10px %s; %s">
                <p style="color: %s; font-weight: bold; margin: 5px 0 0;">%s%s</p>
                <p style="font-size: 12px; color: #fff; margin: 0;">Qtà: %d</p>
                <p style="font-size: 11px; color: %s; margin: 0;">%s</p>
                %s
            </div>
        ]], disabledClass, item.type, disabledStyle, runeData.image, runeData.color, isDisabled and 'filter: grayscale(80%)' or '', runeData.color, runeData.name, levelText, tonumber(item.count), isDisabled and '#999999' or '#aaa', statusText, isDisabled and '<p style="font-size: 10px; color: #ff6b6b; font-weight: bold; margin: 5px 0;">⚠️ Non può essere upgradata</p>' or '')
    end

    print('Client: Invio aggiornamento HTML al NUI e apertura menu')
    -- Mostra il menu, nascondi caricamento e invia i dati delle rune e galeoni insieme
    SendNUIMessage({
        showCrafting = true,
        showLoading = false,
        updateRunes = html,
        galeoniInfo = {
            count = galeoniCount,
            hasEnough = hasEnoughGaleoni
        }
    })
end)

-- Funzione chiamata dal client per richiedere i dati dell'inventario
local function requestInventory()
    TriggerServerEvent('rune:getInventory')
end

-- Funzione chiamata dal client per aggiornare l'inventario
local function updateInventory(data)
    playerInventory = data
end

-- Funzione chiamata dal client per richiedere i dati delle rune
local function requestRuneData()
    TriggerServerEvent('rune:getRuneData')
end

-- Funzione chiamata dal server per inviare i dati delle rune al client
RegisterNetEvent('rune:runeDataResponse', function(data)
    SendNUIMessage({
        updateRuneData = data
    })
end)

-- Funzione chiamata dal client per aggiornare i dati delle rune
local function updateRuneData(data)
    -- Esegui le azioni necessarie con i dati delle rune
    -- Ad esempio, puoi aggiornare l'HTML delle rune nell'interfaccia utente
    -- o eseguire altre azioni
    -- ...
    -- ...
end

-- Funzione chiamata dal client per chiudere il menu di selezione della runa
local function closeRuneSelectionMenu()
    -- Esegui le azioni necessarie per chiudere il menu
    -- Ad esempio, puoi nascondere l'interfaccia utente
    -- o eseguire altre azioni
    -- ...
    -- ...
end

RegisterNUICallback('showUpgradeNotification', function(data, cb)
    print('Client: showUpgradeNotification ricevuto:', json.encode(data))
    if data.success then
        lib.notify({
            type = 'success',
            description = '✨️ Incantesimo Riuscito: ' .. data.message,
            duration = 5000,
            position = 'top',
            icon = '✨️'
        })
        PlaySoundFrontend(-1, "SUCCESS", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
        print('Client: Notifica successo inviata: ' .. data.message)
    else
        lib.notify({
            type = 'error',
            description = '💀 Incantesimo Fallito: ' .. data.message,
            duration = 5000,
            position = 'top',
            icon = '💀'
        })
        PlaySoundFrontend(-1, "ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
        print('Client: Notifica fallimento inviata: ' .. data.message)
    end
    cb('ok')
end)

RegisterNUICallback('triggerInventoryRefresh', function(_, cb)
    TriggerServerEvent('rune:getInventory')
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(_, cb)
    closeCraftingMenu()
    cb('ok')
end)

RegisterNUICallback('selectRune', function(data, cb)
     print('Client: selectRune callback called with data:', data)
     local fullType = data.rune
     local selectedRune = nil

     for _, rune in ipairs(playerInventory) do
         if rune.type == fullType then
             selectedRune = rune
             break
         end
     end

     if not selectedRune then
         lib.notify({ type = 'error', description = 'Non possiedi questa runa!' })
         cb('ok')
         return
     end

     if (selectedRune.level or 0) >= 5 then
         lib.notify({ type = 'info', description = 'Questa runa è al livello massimo!' })
         cb('ok')
         return
     end

     -- Reset main menu state since we're switching to phase 2
     isMenuOpen = false

     -- Switch to phase 2 window
     SendNUIMessage({
         showPhase2 = true,
         selectedRune = selectedRune,
         galeoniRequired = 200
     })

     cb('ok')
 end)

RegisterNUICallback('closePhase2', function(data, cb)
     print('Client: closePhase2 callback called')

     -- Release NUI focus and restore radar
     SetNuiFocus(false, false)
     DisplayRadar(true)

     -- Re-enable player control
     local playerPed = PlayerPedId()
     FreezeEntityPosition(playerPed, false)
     SetPlayerControl(PlayerId(), true, 0)

     -- Re-enable targeting if it was disabled
     if target then
         pcall(function() exports.ox_target:enableTargeting() end)
     end

     cb('ok')
 end)

RegisterNUICallback('triggerUpgrade', function(data, cb)
     print('Client: triggerUpgrade callback called with data:', data)
     local fullType = data.rune

     -- Check galeoni before proceeding
     local galeoni = exports.ox_inventory:Search('count', 'galeoni')
     if galeoni < 200 then
         SendNUIMessage({
             upgradeResult = {
                 success = false,
                 message = 'Non hai abbastanza galeoni (200 richiesti)',
                 noGaleoni = true
             }
         })
         cb('ok')
         return
     end

     TriggerServerEvent('rune:upgrade', fullType)

     cb('ok')
 end)

RegisterNUICallback('startRoulette', function(_, cb)
    local pietraCount = exports.ox_inventory:Search('count', 'pietra_grezza')
    if pietraCount > 0 then
        TriggerServerEvent('pietra:remove', 1)
        TriggerEvent('dalgona:startRoulette', { pietraCount = pietraCount - 1, hasRoulette = true })
        lib.notify({ type = 'info', description = 'Roulette avviata! Pietra consumata.' })
    else
        lib.notify({ type = 'error', description = 'Non hai pietre grezze!' })
    end
    cb('ok')
end)

-- Prop Management
local function cleanupExistingProps()
    if not Config.CraftingTable or not Config.CraftingTable.ModelHash or not Config.FixedPositions or not Config.FixedPositions.CraftingTable then return end
    local modelHash = Config.CraftingTable.ModelHash
    if type(modelHash) == 'string' then
        modelHash = GetHashKey(modelHash)
    end
    local tablePos = Config.FixedPositions.CraftingTable
    local maxDistance = 5.0
    local props = GetGamePool('CObject')
    for _, prop in ipairs(props) do
        if DoesEntityExist(prop) and GetEntityModel(prop) == modelHash then
            local propCoords = GetEntityCoords(prop)
            if #(propCoords - vec3(tablePos.x, tablePos.y, tablePos.z)) <= maxDistance then
                if NetworkGetEntityIsNetworked(prop) then
                    NetworkRequestControlOfEntity(prop)
                    local attempts = 0
                    while not NetworkHasControlOfEntity(prop) and attempts < 20 do
                        Wait(0)
                        NetworkRequestControlOfEntity(prop)
                        attempts += 1
                    end
                end

                SetEntityAsMissionEntity(prop, true, true)
                DeleteEntity(prop)
            end
        end
    end
end

-- Initialization & Threads
local function startMainThread()
    isInitialized = true
    CreateThread(function()
        while isInitialized do
            local sleep = 1000
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            if craftingTableCoords then
                local dist = #(playerCoords - craftingTableCoords)
                if dist <= 2.5 then
                    sleep = 0
                    if not isNearCraftingTable then
                        isNearCraftingTable = true
                        lib.showTextUI('[U] Tavolo da Rune', { position = 'top-center', icon = 'hammer' })
                    end
                    
                    if IsControlJustPressed(0, 303) and not isMenuOpen then
                        openCraftingMenu()
                    end
                elseif isNearCraftingTable then
                    isNearCraftingTable = false
                    lib.hideTextUI()
                    if isMenuOpen then closeCraftingMenu() end
                end
            end
            Wait(sleep)
        end
    end)
end

-- Funzione semplice per spawnare il tavolo alle coordinate statiche
local function spawnCraftingTable()
    -- Rimuovi eventuali prop già presenti con lo stesso modello
    cleanupExistingProps()

    -- Se esiste già un tavolo, rimuovilo prima
    if craftingTableProp and DoesEntityExist(craftingTableProp) then
        print('Client: Rimozione tavolo esistente prima dello spawn')
        pcall(function()
            if target then
                exports.ox_target:removeLocalEntity(craftingTableProp)
            end
        end)
        DeleteEntity(craftingTableProp)
        craftingTableProp = nil
    end
    
    -- Spawn alle coordinate statiche senza controlli
    local pos = Config.FixedPositions.CraftingTable
    local modelHash = Config.CraftingTable.ModelHash
    
    print('Client: SpawnCraftingTable - Spawn diretto a:', pos)
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do 
        Wait(10) 
    end

    local success, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 10.0, false)
    local spawnPos = success and vec3(pos.x, pos.y, groundZ) or pos

    craftingTableProp = CreateObject(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, true, false, false)
    SetEntityRotation(craftingTableProp, Config.CraftingTable.Rotation.x, Config.CraftingTable.Rotation.y, Config.CraftingTable.Rotation.z, 2, true)
    SetEntityCoordsNoOffset(craftingTableProp, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
    PlaceObjectOnGroundProperly(craftingTableProp)
    SetEntityAsMissionEntity(craftingTableProp, true, true)

    -- Rendi il tavolo completamente bloccato a terra
    FreezeEntityPosition(craftingTableProp, true)
    SetEntityInvincible(craftingTableProp, true)
    SetEntityDynamic(craftingTableProp, false)
    SetEntityCollision(craftingTableProp, true, true)
    SetEntityCanBeDamaged(craftingTableProp, false)
    SetEntityHasGravity(craftingTableProp, false)
    SetEntityRecordsCollisions(craftingTableProp, true)

    -- Blocchi aggiuntivi per impedire qualsiasi movimento
    SetEntityVelocity(craftingTableProp, 0.0, 0.0, 0.0)
    SetEntityRotation(craftingTableProp, Config.CraftingTable.Rotation.x, Config.CraftingTable.Rotation.y, Config.CraftingTable.Rotation.z, 2, true)
    SetEntityCoordsNoOffset(craftingTableProp, spawnPos.x, spawnPos.y, spawnPos.z, true, true, true)
    
    craftingTableCoords = GetEntityCoords(craftingTableProp)
    
    print('Client: SpawnCraftingTable - Tavolo spawnato e immobilizzato a:', craftingTableCoords)
    
    SetModelAsNoLongerNeeded(modelHash)
end

-- Funzione di inizializzazione semplice
local function initCraftingTable()
    if not Config.CraftingTable or not Config.CraftingTable.Enabled then 
        print('Client: Crafting table disabilitato')
        return 
    end
    
    -- Spawn diretto senza pulizia complessa
    spawnCraftingTable()
    
    -- Aggiungi ox_target se esiste il tavolo
    if craftingTableProp and DoesEntityExist(craftingTableProp) then
        exports.ox_target:addLocalEntity(craftingTableProp, {
            {
                name = 'rune_crafting',
                icon = 'fas fa-hammer',
                label = 'Tavolo da Rune',
                onSelect = function() openCraftingMenu() end,
                distance = 2.0
            }
        })
        print('Client: Ox target aggiunto al tavolo')
    else
        print('Client: Errore: tavolo non spawnato correttamente')
        startMainThread()
    end
end

-- Lifecycle Events
CreateThread(function()
    -- Inizializzazione semplice senza pulizia complessa
    Wait(1000) -- Aspetta che il gioco sia caricato
    initCraftingTable()
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
local function cleanupCraftingSystem()
    isInitialized = false
    
    -- Chiudi menu se aperto
    if isMenuOpen then closeCraftingMenu() end
    
    -- Disabilita ox_target completamente prima della pulizia
    pcall(function()
        if target then
            exports.ox_target:disableTargeting()
        end
    end)
    
    -- Rimuovi le zone target in modo sicuro
    if craftingTableProp then
        safeRemoveTargetEntity(craftingTableProp)
        -- Aspetta un frame prima di cancellare l'entity
        Wait(0)
        if DoesEntityExist(craftingTableProp) then
            DeleteEntity(craftingTableProp)
        end
        craftingTableProp = nil
    end
    
    -- Nascondi UI
    if lib then lib.hideTextUI() end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cleanupCraftingSystem()
end)

-- Additional Events
RegisterNetEvent('rune:upgradeResult', function(data)
    print('Client: rune:upgradeResult received:', data and json.encode(data) or 'nil')
    if data then
        -- Comment out lib.notify to avoid ox_lib error
        -- if data.success then
        --     lib.notify({ type = 'success', description = data.message })
        -- else
        --     lib.notify({ type = 'error', description = data.message })
        -- end
        SendNUIMessage({ upgradeResult = data })
    else
        print('Client: rune:upgradeResult received with nil data')
    end
end)

RegisterNetEvent('rune:upgradeComplete', function()
    -- Aggiorna l'inventario quando il risultato viene chiuso, non automaticamente
    print('Client: rune:upgradeComplete ricevuto - attendo chiusura risultato per aggiornare inventario')
end)

RegisterNetEvent('dalgona-game:teleportToCraftingTable', function()
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        lib.notify({ type = 'error', description = 'Esci dal veicolo!' })
        return
    end

    if Config.CraftingTable and Config.FixedPositions and Config.FixedPositions.CraftingTable then
        local pos = Config.FixedPositions.CraftingTable
        SetEntityCoords(playerPed, pos.x, pos.y, pos.z)
        lib.notify({ type = 'success', description = 'Teletrasportato!' })
    end
end)

-- Comando test per verificare l'inventario
RegisterCommand('test-rune-inventory', function()
    print('Client: Test inventario rune - Richiesta dati...')
    TriggerServerEvent('rune:getInventory')
end, false)

-- Comando test per simulare upgrade fallito
RegisterCommand('test-rune-downgrade', function()
    print('Client: Test downgrade rune - Simulazione upgrade fallito...')
    -- Simula un upgrade fallito per una runa di livello 2
    TriggerServerEvent('rune:upgrade', 'runa_hp_2')
end, false)

-- Comando test per verificare il controllo galeoni
RegisterCommand('test-galeoni-check', function()
    print('Client: Test controllo galeoni - Verifica fondi...')
    TriggerServerEvent('rune:getInventory')
end, false)

-- ESC Key handler
CreateThread(function()
    while true do
        Wait(0)
        if isMenuOpen and IsControlJustReleased(0, 200) then
            closeCraftingMenu()
        end
    end
end)
