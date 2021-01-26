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
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.before_each(function()
    h.set_sections(g.srv, {{
        filename = 'extensions/main.lua',
        content = [[
            local M = {}
            function M.echo(req)
                return {status = 201, body = req:param('msg')}
            end
            function M.say_meow()
                return {status = 200, body = 'meow'}
            end
            function M.say_woof()
                return {status = 200, body = 'woof'}
            end
            return M
        ]],
    }, {
        filename = 'extensions/config.yml',
        content = box.NULL,
    }})
end)

function g.test_http_disabled()
    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {
                say_meow = {
                    module = 'extensions.main',
                    handler = 'say_meow',
                    events = {{http = {path = '/meow', method = 'get'}}}
                }
            }
        })
    }})

    g.srv:stop()
    g.srv.env['TARANTOOL_HTTP_ENABLED'] = 'false'
    g.srv:start()

    local state = g.srv.net_box:eval([[
        return require('cartridge.confapplier').get_state()
    ]])
    t.assert_equals(state, 'RolesConfigured')

    t.assert_equals(
        g.srv:http_request('get', '/meow', {raise = false}),
        {status = 595, reason = "Couldn't connect to server"}
    )

    g.srv:stop()
    g.srv.env['TARANTOOL_HTTP_ENABLED'] = nil
    g.srv:start()

    t.assert_covers(
        g.srv:http_request('get', '/meow'),
        {status = 200, body = 'meow'}
    )
end

function g.test_removal()
    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {
                say_meow = {
                    module = 'extensions.main',
                    handler = 'say_meow',
                    events = {{http = {path = '/meow', method = 'get'}}}
                }
            }
        })
    }})

    t.assert_covers(
        g.srv:http_request('get', '/meow'),
        {status = 200, body = 'meow'}
    )

    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = 'functions: {}',
    }})

    t.assert_covers(
        g.srv:http_request('get', '/meow', {raise = false}),
        {status = 404}
    )
end

function g.test_segregation()
    -- The same path can be registered for different methods
    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {
                handle_post = {
                    module = 'extensions.main',
                    handler = 'say_meow',
                    events = {{http = {path = '/say', method = 'post'}}}
                },
                handle_head = {
                    module = 'extensions.main',
                    handler = 'say_woof',
                    events = {{http = {path = '/say', method = 'head'}}}
                },
            }
        })
    }})

    t.assert_covers(
        g.srv:http_request('get', '/say', {raise = false}),
        {status = 404}
    )
    t.assert_covers(
        g.srv:http_request('post', '/say'),
        {status = 200, body = 'meow'}
    )
    t.assert_covers(
        g.srv:http_request('head', '/say'),
        {status = 200, body = 'woof'}
    )
end

function g.test_matching()
    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = yaml.encode({functions = {
            handle_any = {
                module = 'extensions.main',
                handler = 'echo',
                events = {{http = {path = '/*any', method = 'any'}}}
            }
        }})
    }})

    t.assert_covers(
        g.srv:http_request('get', '/foo?msg=1'),
        {status = 201, body = '1'}
    )
    t.assert_covers(
        g.srv:http_request('post', '/bar?msg=2'),
        {status = 201, body = '2'}
    )

    h.set_sections(g.srv, {{
        filename = 'extensions/config.yml',
        content = yaml.encode({functions = {
            handle_any = {
                module = 'extensions.main',
                handler = 'echo',
                events = {{http = {path = '/foo', method = 'get'}}}
            }
        }})
    }})

    t.assert_covers(
        g.srv:http_request('get', '/foo?msg=3'),
        {status = 201, body = '3'}
    )
    t.assert_covers(
        g.srv:http_request('post', '/foo', {raise = false}),
        {status = 404}
    )
    t.assert_covers(
        g.srv:http_request('get', '/bar', {raise = false}),
        {status = 404}
    )
end
