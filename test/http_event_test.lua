local fio = require('fio')
local yaml = require('yaml')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

local http = require('http.client')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = test_helper.server_command,
        replicasets = {{
            alias = 'loner',
            uuid = helpers.uuid('a'),
            roles = {'extensions'},
            servers = {{
                instance_uuid = helpers.uuid('a', 'a', 1)
            }},
        }}
    })

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function set_sections(sections)
    return g.cluster.main_server:graphql({
        query = [[
            mutation($sections: [ConfigSectionInput!]) {
                cluster {
                    config(sections: $sections) {}
                }
            }
        ]],
        variables = {sections = sections},
    })
end

local function make_self_http_request(method, path, opts)
    local options = opts or {}
    local server_uri = ("localhost:%s"):format(g.cluster.main_server.http_port)

    return http.request(method, server_uri .. path, nil, options)
end

function g.test_http_disabled()
    os.setenv('TARANTOOL_HTTP_ENABLED', 'FALSE')
    g.cluster.main_server:stop()
    g.cluster.main_server:start()

    g.cluster.main_server.net_box:eval([[
        local cartridge = require('cartridge')

        local conf = {}
        conf['extensions/config.yml'] = require('yaml').encode({
            functions = {x = {
                module = 'extensions.box',
                handler = 'cat',
                events = {{
                    http = { path = '/cat', method = 'GET' }
                }}
            }}
        })
        conf['extensions/box.lua'] = "return { cat = function() end }"

        return cartridge.config_patch_clusterwide(conf)
    ]])

    local res = make_self_http_request('GET', '/cat', {timeout = 2})
    t.assert_items_equals(res, {reason = "Couldn't connect to server", status = 595})
end

function g.test_http_event_removing()
    os.setenv('TARANTOOL_HTTP_ENABLED', 'TRUE')
    g.cluster.main_server:stop()
    g.cluster.main_server:start()

    local config = {{
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {x = {
                module = 'extensions.box',
                handler = 'cat',
                events = {{
                    http = { path = '/cat', method = 'GET' }
                }}
            }}
        })
    }, {
        filename = 'extensions/box.lua',
        content = 'return { cat = function() return { status = 200, body = \"Meow\" } end}'
    }}

    set_sections(config)
    local res = make_self_http_request('GET', '/cat')
    t.assert_items_equals(
        { status = res.status, body = res.body},
        { status = 200, body = "Meow"}
    )

    set_sections({{
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {}
        })
    }})
    t.assert_is(
        make_self_http_request('GET', '/cat').status,
        404
    )
end
