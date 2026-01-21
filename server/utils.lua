-- =============================================================================
-- Dalgona Game - Server Utilities
-- =============================================================================

-- Debug print function
function debugPrint(message)
    if Config.Debug then
        print('^2[Incanta Pietra]^7 ' .. tostring(message))
    end
end

-- Wait with condition check
function WaitWithCondition(duration, conditionCb)
    local stopAt = GetGameTimer() + duration
    while conditionCb() and GetGameTimer() < stopAt do
        Wait(50)
    end
end

-- Get random element from table
function tableRandom(tbl)
    return tbl[math.random(#tbl)]
end

-- Shuffle table
function tableShuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

-- Deep copy table
function tableDeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[tableDeepCopy(orig_key)] = tableDeepCopy(orig_value)
        end
        setmetatable(copy, tableDeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end
