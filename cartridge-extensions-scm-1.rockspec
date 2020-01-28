package = 'cartridge-extensions'
version = 'scm-1'
source  = {
    branch = 'master',
    url = 'git+https://github.com/tarantool/cartridge-extensions.git'
}

dependencies = {
    'lua >= 5.1',
    'checks >= 3.0.0',
    'errors >= 2.1.0-1',
    'cartridge',
}

description = {
    summary = 'Tarantool opensource cartridge-extensions module';
    homepage = 'https://github.com/tarantool/cartridge-extensions';
    detailed = [[
        A ready-to-use Lua module cartridge-extensions for tarantool-cartridge.
    ]];
}

external_dependencies = {
    TARANTOOL = {
        header = 'tarantool/module.h',
    },
}

build = {
    type = 'builtin',
    modules = {
        ['extensions'] = 'extensions.lua',
    }
}