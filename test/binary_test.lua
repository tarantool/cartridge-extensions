local fio = require('fio')
local yaml = require('yaml')
local t = require('luatest')
local h = require('test.helper')
local g = t.group()

g.before_all(function()
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
    g.srv = g.cluster.main_server
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)


function g.test_runtime()
    local extensions_cfg = yaml.encode({
        functions = {
            operate = {
                module = 'extensions.main',
                handler = 'operate',
                events = {{
                    binary = {path = 'operate'}
                }}
            },
            math_abs = {
                module = 'math',
                handler = 'abs',
                events = {{
                    binary = {path = 'math_abs'}
                }}
            }
        }
    })

    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = extensions_cfg,
    }, {
        filename = 'extensions/main.lua',
        content = [[
            local function M()
                return require('extensions.main')
            end

            local function operate()
                return 1
            end

            return {
                M = M,
                require = require,
                operate = operate,
            }
        ]],
    }})

    t.assert_equals(g.srv.net_box:call('math_abs', {-3}), 3)
    t.assert_equals(g.srv.net_box:call('operate'), 1)
    g.srv.net_box:eval([[
        assert(package.loaded['extensions.main'], 'Extension not loaded')
        local M = require('extensions.main')
        assert(M == M.M(), 'Extension was reloaded twice')
        assert(require ~= M.require, 'Upvalue "require" is broken')
    ]])

    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = extensions_cfg,
    }, {
        filename = 'extensions/main.lua',
        content = [[
            local function operate()
                return 2
            end

            return {
                operate = operate,
            }
        ]],
    }})

    t.assert_equals(g.srv.net_box:call('operate'), 2)

    t.assert_equals(h.get_state(g.srv), 'RolesConfigured')
end
