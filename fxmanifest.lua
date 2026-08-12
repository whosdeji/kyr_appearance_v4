fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kyr_appearance'
author 'Kyrell'
description 'mp_freemode appearance creator (post ox_core character creation) - excludes clothing'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/camera.lua',
    'client/appearance.lua',
    'client/lockers.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

dependencies {
    'ox_core',
    'ox_lib',
    'oxmysql',
    'ox_target'
}