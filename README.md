## Cartridge-extensions

This module represents new role `extensions` for cartridge.

All `extensions/*.lua` files will be loaded as Lua modules.
They'll be accessible through

```lua
local banking = require('extensions.banking')
```

### How to export my functions?

Also `extensions/config.yml` describes how to export those modules in
serverless style.

For now we'll support two types of events:
- `binary`
- `http`

HTTP event supports any kind of HTTP's methods: GET, POST, PUT and etc.

Here is a little example:

```yml
functions:
  transfer_money:
    module: banking
    handler: transfer_money
    events:
    - binary:
      # It'll assign _G.__transfer_money = banking.transfer_money
        path: __transfer_money

  get_balance:
    module: banking
    handler: http_get_balance
    events:
    - http:
      # It'll create the new HTTP endpoint by the next path:
      # http://<your_domain>:<http_port>/get_balance
        path: "/get_balance"
        method: GET
```
