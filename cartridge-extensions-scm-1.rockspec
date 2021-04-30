package = 'cartridge-extensions'
version = 'scm-1'
source  = {
    branch = 'master',
    url = 'git+https://github.com/tarantool/cartridge-extensions.git'
}

dependencies = {
    'lua >= 5.1',
    'cartridge',
    'checks >= 3.0.0-1, < 4',
    'errors >= 2.1.0-1, < 3',
}

description = {
    summary = 'Tarantool opensource cartridge-extensions module';
    homepage = 'https://github.com/tarantool/cartridge-extensions';
    detailed = [[
        A ready-to-use Lua module cartridge-extensions for tarantool-cartridge.
    ]];
}

build = {
    type = 'builtin',
    modules = {
        ['extensions'] = 'extensions.lua',
    }
}
