fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Code Eider'
description 'CE Base Zone Script'
version '1.0.0'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua'
}

client_scripts {
  '@PolyZone/client.lua',
  '@PolyZone/BoxZone.lua',
  '@PolyZone/EntityZone.lua',
  '@PolyZone/CircleZone.lua',
  '@PolyZone/ComboZone.lua',
  'client.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/script.js'
}

dependencies {
  'ox_inventory',
  'ox_lib',
  'ox_target',
  'PolyZone',
  'oxmysql'
}

