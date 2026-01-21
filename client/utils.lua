-- =============================================================================
-- Dalgona Game - Client Utilities
-- =============================================================================

-- Show notification
function showNotification(message)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, false)
end

-- Draw 3D text at position
function Draw3DText(x, y, z, text, textSize)
    textSize = textSize or 1.15
    
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = GetDistanceBetweenCoords(p.x, p.y, p.z, x, y, z, 1)
    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    
    if onScreen then
        SetTextScale(0.0 * scale, textSize * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Draw indicator marker
function DrawIndicator(location, color)
    if HasStreamedTextureDictLoaded("squidgame") then
        local scale = 3.2
        DrawMarker(
            9, location,
            0.0, 0.0, 0.0,
            90.0, 90.0, 0.0,
            scale, scale, scale,
            color[1], color[2], color[3], color[4],
            false, true, 2, false,
            "squidgame", "3",
            false
        )
    else
        RequestStreamedTextureDict("squidgame", true)
    end
end

-- Play animation on ped
function PlayAnimation(ped, anim)
    if not DoesAnimDictExist(anim.dict) then
        return false
    end

    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do
        Wait(0)
    end

    TaskPlayAnim(ped, anim.dict, anim.name, anim.blendInSpeed, anim.blendOutSpeed, anim.duration, anim.flag, anim.playbackRate, false, false, false, '', false)
    RemoveAnimDict(anim.dict)
    
    return true
end

-- Audio configuration
local audiobank = 'audiodirectory/dalgonagame_audiobank'
local soundset = 'dalgonagame_soundset'
local sounds = {
    'pistol_shot_a', 'pistol_shot_b',
    'pistol_shot_c', 'pistol_shot_d',
    'pistol_shot_e', 'pistol_shot_f'
}

-- Play pistol sound at coordinates
function PlayPistolSound(coords, isNetworked)
    local timeoutAt = GetGameTimer() + 1500
    
    while not RequestScriptAudioBank(audiobank, false) do
        Wait(0)
        if GetGameTimer() >= timeoutAt then
            return false
        end
    end
    
    local sound = sounds[math.random(#sounds)]
    local soundId = GetSoundId()
    PlaySoundFromCoord(soundId, sound, coords.x, coords.y, coords.z, soundset, false, 50.0, isNetworked)
    ReleaseSoundId(soundId)
    ReleaseNamedScriptAudioBank(audiobank)
    
    return true
end

-- Play pistol sound frontend
function PlayPistolSoundFrontend()
    local timeoutAt = GetGameTimer() + 1500
    
    while not RequestScriptAudioBank(audiobank, false) do
        Wait(0)
        if GetGameTimer() >= timeoutAt then
            return false
        end
    end
    
    local sound = sounds[math.random(#sounds)]
    local soundId = GetSoundId()
    PlaySoundFrontend(soundId, sound, soundset)
    ReleaseSoundId(soundId)
    ReleaseNamedScriptAudioBank(audiobank)
    
    return true
end

-- Headshot blood effect
function callBloodHeadshotEffectOnPed(ped)
    local timeoutAt = GetGameTimer() + 1500
    local fxName = "core"
    local effectName = "blood_headshot"
    
    RequestNamedPtfxAsset(fxName)
    while not HasNamedPtfxAssetLoaded(fxName) do
        Wait(0)
        if GetGameTimer() >= timeoutAt then
            return false
        end
    end
    
    local SKEL_HEAD = 31086
    SetPtfxAssetNextCall(fxName)
    StartParticleFxNonLoopedOnPedBone(effectName, ped, 0.100, -0.4, 0.0, 90.0, 0.0, 0.0, SKEL_HEAD, 5.0, false, false, false)
    createBloodDecalBehindPed(ped)
    
    return true
end

-- Create blood decal behind ped
function createBloodDecalBehindPed(ped)
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local decalCoords = coords + forward * -0.5
    
    RequestDecalTexture("BloodPool")
    while not HasDecalTextureLoaded("BloodPool") do
        Wait(0)
    end
    
    AddDecal(0, decalCoords.x, decalCoords.y, decalCoords.z, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 255, 0, 0, 255, false, 0.0, false)
end
