fx_version 'cerulean'
game 'gta5'

name 'cinema_doppler'
description 'Doppler cinema YouTube screen with custom HTML player'
author 'You + ChatGPT'

lua54 'yes'

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

files {
    'ui/index.html',
    'ui/script.js',
    'ui/style.css'
}

-- Not strictly required for DUI, but fine to declare
ui_page 'ui/index.html'
