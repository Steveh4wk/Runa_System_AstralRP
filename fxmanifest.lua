-- =============================================================================
-- Dalgona Game - Single Player Edition
-- Spawn prop_rock_4_c at player spawn for Dalgona minigame interaction
-- On success: automatic diamond drop
-- =============================================================================
fx_version 'cerulean'
games { 'gta5' }
author 'Stefano Luciano Corp. Developed Script Runa_System 1.0'
version '1.1.3'
lua54 'yes'

-- IMPORTANT: Add this resource to your server.cfg:
-- ensure Runa_System

dependencies {
    '/onesync',
    'ox_lib',
    'ox_inventory',
}

shared_scripts {
    'shared/variables.lua',
    'shared/events.lua',
    'shared/statebags.lua',
    'shared/commands.lua',

    'shared/utils.lua',

    'config.lua',
    'locale.lua',
    'locales/*.lua',
}

client_scripts {
    'client/utils.lua',
    'client/framework.lua',
    'client/main.lua',
    'client/timer.lua',
    'client/countdown.lua',
    'client/skin.lua',
    'client/skinData.lua',
    'client/cutscene.lua',
    'client/freezePlayer.lua',
    'client/nui.lua',
    'client/minigame.lua',
    'client/npc.lua',
    'client/decals.lua',
    'client/rockInteraction.lua',
    'client/craftingTable.lua',
}

server_scripts {
    'server/utils.lua',
    'server/framework.lua',
    'server/main.lua',
}

ui_page 'ui/index.html'
files {
    'ui/*.js',
    'ui/*.css',
    'ui/*.html',
    'ui/*.mp3',
    'ui/*.wav',
}

-- Sounds
file 'audio/data/dalgona_sounds.dat54.rel'
data_file 'AUDIO_SOUNDDATA' 'audio/data/dalgona_sounds.dat'
file 'audio/audiodirectory/dalgonagame_audiobank.awc'
data_file 'AUDIO_WAVEPACK' 'audio/audiodirectory'

-- Prop
file 'stream/props/dalgona_candies.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/dalgona_candies.ytyp'

escrow_ignore {
    '**/*',
    '*',
}

-- Minigame Textures
file 'stream/minigame/dalgona_textures.ytd'
data_file 'DLC_ITYP_REQUEST' 'stream/minigame/dalgona_textures.ytd'
