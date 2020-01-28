local fio = require('fio')

local helper = {}

helper.root = fio.dirname(fio.abspath(package.search('extensions')))
helper.server_command = fio.pathjoin(helper.root, 'test', 'srv_basic.lua')

function helper.table_find_by_attr(tbl, key, value)
    for _, v in pairs(tbl) do
        if v[key] == value then
            return v
        end
    end
end

return helper
