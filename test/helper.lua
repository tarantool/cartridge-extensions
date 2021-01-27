local fio = require('fio')

local helper = table.copy(require('cartridge.test-helpers'))

helper.root = fio.dirname(fio.abspath(package.search('extensions')))
helper.server_command = fio.pathjoin(helper.root, 'test', 'srv_basic.lua')

function helper.table_find_by_attr(tbl, key, value)
    for _, v in pairs(tbl) do
        if v[key] == value then
            return v
        end
    end
end

function helper.set_sections(srv, sections)
    return srv:graphql({
        query = [[
            mutation($sections: [ConfigSectionInput!]) {
                cluster {config(sections: $sections) {}}
            }
        ]],
        variables = {sections = sections},
    })
end

function helper.get_state(srv)
    return srv.net_box:eval([[
        return require('cartridge.confapplier').get_state()
    ]])
end

return helper
