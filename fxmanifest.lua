fx_version 'cerulean'
game 'gta5'

name 'ps-banking'
author 'Project Sloth, redesign by: Rafaell#0202'
version '1.0.4'

ui_page 'html/index.html'
-- ui_page 'http://localhost:5173'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/**/*',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/**/*',
}

files {
    'html/**/*',
    'locales/**/*',
}

dependencies {
    'ox_lib',
    'oxmysql'
}

lua54 'yes'

provides { 'qb-banking', 'qb-management' }
