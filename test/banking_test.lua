local fio = require('fio')
local checks = require('checks')
local t = require('luatest')
local h = require('test.helper')
local g = t.group()

local utils = require('cartridge.utils')

local function lstree(path)
    local files = {}

    local function _ls(root, relpath)
        checks('string', 'string')
        for _, f in pairs(fio.listdir(fio.pathjoin(root, relpath))) do
            if fio.path.is_dir(fio.pathjoin(root, relpath, f)) then
                _ls(root, fio.pathjoin(relpath, f))
            else
                table.insert(files, fio.pathjoin(relpath, f))
            end
        end
    end

    _ls(path, '')
    return files
end

g.before_all = function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = h.server_command,
        replicasets = {{
            alias = 'loner',
            roles = {'extensions'},
            servers = 1,
        }},
    })

    g.cluster:start()

    local config_path = fio.pathjoin(debug.sourcedir(), 'banking_config')
    local config_files = lstree(config_path)
    t.assert_items_equals(config_files, {
        'README.md',
        'schema.yml',
        'extensions/config.yml',
        'extensions/banking.lua',
    })

    local sections = {}
    for _, f in pairs(config_files) do
        table.insert(sections, {
            filename = f,
            content = utils.file_read(fio.pathjoin(config_path, f)),
        })
    end

    h.set_sections(g.cluster.main_server, sections)
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_banking()
    local srv = g.cluster.main_server

    srv.net_box:call('customer_add', {1, 'Ivan'})
    srv.net_box:call('account_add', {1, 1, 'default'})

    srv.net_box:call('customer_add', {2, 'Boris'})
    srv.net_box:call('account_add', {2, 2, 'default'})

    srv.net_box:call('transfer_money', {1, 2, 20})

    local accounts = srv.net_box.space.account:select()
    t.assert_equals(accounts[1], {1, 1, 'default', -20})
    t.assert_equals(accounts[2], {2, 2, 'default', 20})
    t.assert_equals(#accounts, 2)
end
