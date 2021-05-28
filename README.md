## Cartridge-extensions

This module represents new role `extensions` for Cartridge.

All `extensions/*.lua` files will be loaded as Lua modules.
They'll be accessible through

```lua
local mymodule = require('extensions.mymodule')
```

### How to export my functions?

Also `extensions/config.yml` describes how to export those modules in
serverless style.

For now there're two supported types of events:
- `binary`,
- `http`.

HTTP event supports any kind of methods: `GET`, `POST`, `PUT`, etc.

Here is a little example:

```yml
functions:
  transfer_money:
    module: extensions.banking
    handler: transfer_money
    events:
    - binary:
        # It'll assign _G.__transfer_money = banking.transfer_money
        path: __transfer_money

  get_balance:
    module: extensions.banking
    handler: http_get_balance
    events:
    - http:
        path: /get_balance
        method: GET
```
