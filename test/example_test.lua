local fio = require('fio')
local fun = require('fun')
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

local function uncomment(text, prefix)
    local lines = fun.map(
        function(l) return l:gsub(prefix, '') end,
        text:split('\n')
    ):totable()
    return table.concat(lines, '\n')
end

function g.test_example_config()
    local sections = {}
    for _, s in ipairs(h.get_sections(g.srv)) do
        if s.filename:match('^extensions/.+%.yml$') then
            table.insert(sections, {
                filename = s.filename,
                content = uncomment(s.content, '^# ')
            })
        elseif s.filename:match('^extensions/.+%.lua$') then
            table.insert(sections, {
                filename = s.filename,
                content = uncomment(s.content, '^-- ')
            })
        end
    end

    h.set_sections(g.srv, sections)

    t.assert_covers(
        g.srv:http_request('get', '/hello?name=Cartridge'),
        {status = 200, body = 'Hello, Cartridge!\n'}
    )
end
