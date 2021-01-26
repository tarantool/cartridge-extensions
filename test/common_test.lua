local fio = require('fio')
local yaml = require('yaml')
local t = require('luatest')
local h = require('test.helper')
local g = t.group()

local error_prefix = "Invalid extensions config: "

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

function g.test_require_errors()
    t.assert_error_msg_equals(
        "extensions/main.lua:1: bad argument #1 to 'require'" ..
        " (string expected, got cdata)",
        h.set_sections, g.srv, {{
            filename = 'extensions/main.lua',
            content = 'require(box.NULL)',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/main.lua:1: loop or previous error loading" ..
        " module 'extensions.main'",
        h.set_sections, g.srv, {{
            filename = 'extensions/main.lua',
            content = 'require("extensions.main")',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/main.lua:1: unexpected symbol near '!'",
        h.set_sections, g.srv, {{
            filename = 'extensions/main.lua',
            content = '! Syntax error',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/main.lua:1: ###",
        h.set_sections, g.srv, {{
            filename = 'extensions/main.lua',
            content = 'error("###")',
        }}
    )

    t.assert_error_msg_equals(
        "module 'extensions.main' not found:\n" ..
        "\tno section 'extensions/main.lua' in config",
        h.set_sections, g.srv, {{
            filename = 'extensions/main.lua.yml',
            content = '{"This is not a script"}',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/pupa.lua:1: module 'extensions.lupa' not found:\n" ..
        "\tno section 'extensions/lupa.lua' in config",
        h.set_sections, g.srv, {{
            filename = 'extensions/pupa.lua',
            content = 'require("extensions.lupa")',
        }}
    )

    t.assert_error_msg_matches(
        "extensions/pupa%.lua:1: module 'lupa' not found:\n" ..
        "\tno field package.preload%['lupa'%].+",
        h.set_sections, g.srv, {{
            filename = 'extensions/pupa.lua',
            content = 'require("lupa")',
        }, {
            filename = 'lupa.lua',
            content = 'return {}',
        }}
    )

    t.assert_equals(h.get_state(g.srv), 'RolesConfigured')
end

function g.test_functions_errors()
    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions (table expected, got cdata)',
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = box.NULL,
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions (table keys must be strings, got number)',
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {1},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"] (table expected, got cdata)',
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = box.NULL},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"].module (string expected, got cdata)',
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = box.NULL,
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"].handler (string expected, got number)',
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = '',
                    handler = 0,
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"].events (table expected, got boolean)',
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = 'math',
                    handler = 'atan2',
                    events = false,
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no module 'unknown' to handle function 'x'",
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = 'unknown',
                    handler = 'f',
                    events = {},
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no function 'cat' in module 'box'" ..
        " to handle function 'x'",
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = 'box',
                    handler = 'cat',
                    events = {},
                }},
            }),
        }}
    )
end

function g.test_export_errors()
    local extensions_cfg = yaml.encode({
        functions = {F = {
            module = 'extensions.main',
            handler = 'operate',
            events = {{
                binary = {path = 'operate'}
            }}
        }}
    })

    t.assert_error_msg_equals(
        error_prefix .. "no module 'extensions.main'" ..
        " to handle function 'F'",
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no function 'operate' in module 'extensions.main'" ..
        " to handle function 'F'",
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }, {
            filename = 'extensions/main.lua',
            content = 'return false',
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no function 'operate' in module 'extensions.main'" ..
        " to handle function 'F'",
        h.set_sections, g.srv, {{
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }, {
            filename = 'extensions/main.lua',
            content = 'return {operate = "not-a-function"}',
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "collision of binary event 'operate'" ..
        " to handle function 'F'",
        h.set_sections, g.srv, {{
            filename = 'extensions/main.lua',
            content = 'return {operate = function() end}',
        }, {
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {F = {
                    module = 'extensions.main',
                    handler = 'operate',
                    events = {
                        {binary = {path = 'operate'}},
                        {binary = {path = 'operate'}},
                    },
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "can't override global 'box'" ..
        " to handle function 'F'",
        h.set_sections, g.srv, {{
            filename = 'extensions/main.lua',
            content = 'return {operate = function() end}',
        }, {
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {F = {
                    module = 'extensions.main',
                    handler = 'operate',
                    events = {
                        {binary = {path = 'box'}},
                    },
                }},
            }),
        }}
    )

    t.assert_equals(h.get_state(g.srv), 'RolesConfigured')
end
