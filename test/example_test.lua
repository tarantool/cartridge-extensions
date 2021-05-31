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

local function grab_example_cfg(server)
    local sections = {}
    for _, s in ipairs(h.get_sections(server)) do
        require('log').info(s.filename)
        if s.filename:match('^extensions/.*$') then
            sections[s.filename] = s.content
        end
    end
    return sections
end

function g.test_example_config()
    local cfg_key = 'extensions/config.yml'
    local code_key = 'extensions/example.lua'

    local examples = g.srv.net_box:eval([[
        return require('cartridge.vars').new('cartridge.roles.extensions').example
    ]])

    t.assert_equals(grab_example_cfg(g.srv), { [cfg_key] = examples[cfg_key] })

    -- test set example.lua works
    h.set_sections(g.srv, {{
        filename = code_key,
        content = examples[code_key]
    }})
    t.assert_equals(grab_example_cfg(g.srv), examples)

    -- test unset example.lua works
    h.set_sections(g.srv, {{
        filename = code_key,
        content = nil
    }})
    t.assert_equals(grab_example_cfg(g.srv), { [cfg_key] = examples[cfg_key] })

    -- test change example.lua works
    examples[code_key] = '\n-- require("log").info("smth")\n' .. examples[code_key]
    h.set_sections(g.srv, {{
        filename = code_key,
        content = examples[code_key]
    }})
    t.assert_equals(grab_example_cfg(g.srv), examples)

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
