-- Framework support for QB-Core and luman-bridge
-- Uses QB-Core notify if available, otherwise falls back to native notification

Framework = {}

-- Try QB-Core notification first
function Framework.showNotification(message)
    -- Try QB-Core export
    if exports['qb-core'] and exports['qb-core']:GetCoreObject() then
        local QBCore = exports['qb-core']:GetCoreObject()
        QBCore.Functions.Notify(message)
        return
    end
    
    -- Try ox_lib notification
    if exports['ox_lib'] and exports['ox_lib'].notify then
        exports['ox_lib']:notify({
            title = 'Dalgona Game',
            description = message,
            type = 'inform'
        })
        return
    end
    
    -- Fallback to native FiveM notification
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, false)
end
