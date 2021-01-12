local checks = require('checks')
local json = require('json')
-- local extensions = require('cartridge').service_get('extensions')

local function customer_add(customer_id, fullname)
    checks('number', 'string')
    return box.space.customer:insert(
        {customer_id, fullname}
    )
end

local function http_customer_add(request)
    checks('table')
    local data = request:json()

    local ok, err = box.space.customer:insert(
        {tonumber(data.customer_id), data.fullname}
    )

    return { body = json.encode({ status = not err and "Success" or "Fail", result = ok}),
             status = not err and 200 or 500 }
end

local function account_add(customer_id, account_id, name)
    checks('number', 'number', 'string')
    return box.space.account:insert(
        {tonumber(customer_id), account_id, name, 0}
    )
end

local function http_account_add(request)
    checks('table')
    local data = request:json()

    local ok, err = box.space.account:insert(
        {tonumber(data.customer_id), tonumber(data.account_id), data.name, 0}
    )

    return { body = json.encode({ status = not err and "Success" or "Fail", result = ok}),
             status = not err and 200 or 500 }
end

local function transfer_money(account_from, account_to, amount)
    box.begin()
    box.space.account:update({account_to}, {{'+', 4, amount}})
    box.space.account:update({account_from}, {{'-', 4, amount}})
    box.commit()
    return true
end

return {
    customer_add = customer_add,
    http_customer_add = http_customer_add,
    account_add = account_add,
    http_account_add = http_account_add,
    transfer_money = transfer_money,
}
