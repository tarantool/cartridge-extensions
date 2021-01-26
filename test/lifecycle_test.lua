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
        }}
    })

    g.cluster:start()
    g.srv = g.cluster.main_server
    h.set_sections(g.srv, {{
        filename = 'extensions/main.lua',
        content = [[
            local function ping()
                return {status = 204}
            end
            return {ping = ping}
        ]],
    }, {
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {
                ping = {
                    module = 'extensions.main',
                    handler = 'ping',
                    events = {{
                        binary = {path = 'ping'},
                        http = {path = 'ping', method = 'get'},
                    }}
                }
            }
        })
    }})
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_stop()
    local edit_topology = [[
        local ok, err = require('cartridge').admin_edit_topology({
            replicasets = {...}
        })
        assert(ok, tostring(err))
        return true
    ]]

    -- Disable
    g.srv.net_box:eval(edit_topology, {{
        uuid = g.srv.replicaset_uuid,
        roles = {},
    }})

    t.assert_error_msg_equals(
        "Procedure 'ping' is not defined",
        function() return g.srv.net_box:call('ping') end
    )
    t.assert_covers(
        g.srv:http_request('get', '/ping', {raise = false}),
        {status = 404}
    )

    -- Re-enable
    g.srv.net_box:eval(edit_topology, {{
        uuid = g.srv.replicaset_uuid,
        roles = {'extensions'},
    }})

    t.assert_equals(
        g.srv.net_box:call('ping'),
        {status = 204}
    )
    t.assert_covers(
        g.srv:http_request('get', '/ping'),
        {status = 204}
    )
end

function g.test_reload()
    local get_routes_count = [[
        local httpd = require('cartridge').service_get('httpd')
        return #httpd.routes
    ]]
    local routes_count = g.srv.net_box:eval(get_routes_count)

    t.assert_equals(
        {g.srv.net_box:call('package.loaded.cartridge.reload_roles')},
        {true, nil}
    )

    t.assert_equals(
        g.srv.net_box:call('ping'),
        {status = 204}
    )
    t.assert_covers(
        g.srv:http_request('get', '/ping'),
        {status = 204}
    )

    t.assert_equals(
        g.srv.net_box:eval(get_routes_count),
        routes_count
    )
end
