fx_version 'cerulean'
game 'gta5'

author 'itsshero'
description 'spawn ped'
version '1.0.0'
lua54 'yes'
client_script {
    'client/**.lua',
}

server_script {
    'server/**.lua',
}

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

ui_page "html/index.html"

files {
    "html/index.html",
    "html/style.css",
    "html/script.js"
}